import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide UserInfo;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import '../config/keys.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import 'notification_service.dart';

enum CallStatus { idle, ringing, dialling, connected, busy, ended }

class VoiceCallService extends ChangeNotifier {
  RtcEngine? _engine;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AuthService _authService = AuthService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  bool _isJoined = false;
  bool _isMuted = false;
  bool _isSpeaker = true;
  int? _remoteUid;
  UserModel? _remoteUser;
  CallStatus _callStatus = CallStatus.idle;
  String? _currentChannelId;
  StreamSubscription? _callDocSubscription;

  bool get isJoined => _isJoined;
  bool get isMuted => _isMuted;
  bool get isSpeaker => _isSpeaker;
  int? get remoteUid => _remoteUid;
  UserModel? get remoteUser => _remoteUser;
  CallStatus get callStatus => _callStatus;
  String? get currentChannelId => _currentChannelId;

  Future<void> initEngine() async {
    if (_engine != null) return;

    await [
      Permission.microphone,
      Permission.bluetoothConnect,
    ].request();

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(const RtcEngineContext(
      appId: AppKeys.agoraAppId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    _addEventHandlers();
    await _engine!.enableAudio();
    await _engine!.setAudioProfile(
      profile: AudioProfileType.audioProfileDefault,
      scenario: AudioScenarioType.audioScenarioGameStreaming,
    );
  }

  void _addEventHandlers() {
    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          _isJoined = true;
          _callStatus = CallStatus.connected;
          stopRinging();
          notifyListeners();
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) async {
          _remoteUid = remoteUid;
          _callStatus = CallStatus.connected;
          stopRinging(); 
          notifyListeners();
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          endCall();
        },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          _isJoined = false;
          _remoteUid = null;
          notifyListeners();
        },
      ),
    );
  }

  String getChannelId(String uid1, String uid2) {
    List<String> ids = [uid1, uid2];
    ids.sort();
    return ids.join('_');
  }

  Future<void> makeCall({required UserModel receiver}) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _remoteUser = receiver;
    _currentChannelId = getChannelId(currentUser.uid, receiver.id);
    _callStatus = CallStatus.dialling;
    notifyListeners();

    // 1. Create call document for signaling status
    await _db.collection('calls').doc(_currentChannelId).set({
      'callerId': currentUser.uid,
      'callerName': currentUser.displayName ?? 'User',
      'callerPic': currentUser.photoURL,
      'receiverId': receiver.id,
      'channelId': _currentChannelId,
      'status': 'dialling',
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 2. Trigger the Incoming Call UI via Notification (Adapted logic)
    await NotificationService().sendNotificationToUser(
      targetUserId: receiver.id,
      title: 'Incoming Call',
      body: '${currentUser.displayName ?? 'Someone'} is calling you',
      rideId: 'CALL_$_currentChannelId',
      callerId: currentUser.uid,
      token: "", // CHOICE B: Testing mode
    );

    _callDocSubscription = _db.collection('calls').doc(_currentChannelId).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final status = snapshot.data()?['status'];
        if (status == 'busy') {
          _callStatus = CallStatus.busy;
          stopRinging();
          notifyListeners();
          Future.delayed(const Duration(seconds: 3), () => endCall());
        } else if (status == 'rejected') {
          endCall();
        } else if (status == 'connected' && _callStatus != CallStatus.connected) {
           _callStatus = CallStatus.connected;
           stopRinging();
           notifyListeners();
        }
      } else if (_callStatus != CallStatus.connected) {
        endCall();
      }
    });

    await startRinging(isOutgoing: true);
    await joinChannel(_currentChannelId!, "");
    
    _saveCallLog({
      'receiverId': receiver.id,
      'receiverName': receiver.name,
      'receiverPic': receiver.profilePic,
    }, 'outgoing');
  }

  Future<void> acceptCall(Map<String, dynamic> callData) async {
    _currentChannelId = callData['channelId'];
    String callerId = callData['callerId'];
    _remoteUser = await _authService.getUserData(callerId);
    
    await stopRinging();
    
    await _db.collection('calls').doc(_currentChannelId).update({
      'status': 'connected',
    });

    await joinChannel(_currentChannelId!, "");
    _saveCallLog(callData, 'incoming');
  }

  Future<void> rejectCall(Map<String, dynamic> callData, {bool isBusy = false}) async {
    final channelId = callData['channelId'];
    await _db.collection('calls').doc(channelId).update({
      'status': isBusy ? 'busy' : 'rejected',
    });
    if (isBusy) {
      _saveCallLog(callData, 'missed');
    }
    endCall();
  }

  Future<void> endCall() async {
    await stopRinging();
    _callDocSubscription?.cancel();
    
    if (_currentChannelId != null) {
      // Update status to ended so receiver can auto-pop
      try {
        await _db.collection('calls').doc(_currentChannelId).update({'status': 'ended'});
        // Delete after a short delay or immediately
        await _db.collection('calls').doc(_currentChannelId).delete();
      } catch (e) {
        debugPrint("Error ending call doc: $e");
      }
    }
    
    await _engine?.leaveChannel();
    
    _isJoined = false;
    _remoteUid = null;
    _remoteUser = null;
    _isMuted = false;
    _callStatus = CallStatus.idle;
    _currentChannelId = null;
    notifyListeners();
  }

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  Future<void> _saveCallLog(Map<String, dynamic> callData, String type) async {
    final myUid = _currentUserId;
    if (myUid == null) return;

    String? otherId;
    String? otherName;
    String? otherPic;

    if (type == 'outgoing') {
      otherId = callData['receiverId'];
      otherName = callData['receiverName'];
      otherPic = callData['receiverPic'];
    } else {
      otherId = callData['callerId'];
      otherName = callData['callerName'];
      otherPic = callData['callerPic'];
    }

    if (otherId == null) return;

    await _db.collection('users').doc(myUid).collection('call_history').add({
      'otherId': otherId,
      'otherName': otherName,
      'otherPic': otherPic,
      'type': type, 
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': type != 'missed',
    });
    
    if (type == 'outgoing') {
      final myUser = await _authService.getUserData(myUid);
      await _db.collection('users').doc(otherId).collection('call_history').add({
        'otherId': myUid,
        'otherName': myUser?.name,
        'otherPic': myUser?.profilePic,
        'type': 'incoming',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': true,
      });
    }
  }

  Future<void> markCallAsRead(String logId) async {
    final uid = _currentUserId;
    if (uid == null) return;
    await _db.collection('users').doc(uid).collection('call_history').doc(logId).update({'isRead': true});
  }

  Future<void> deleteCallLog(String logId) async {
    final uid = _currentUserId;
    if (uid == null) return;
    await _db.collection('users').doc(uid).collection('call_history').doc(logId).delete();
  }

  Future<void> startRinging({bool isOutgoing = false}) async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      if (isOutgoing) {
        await _audioPlayer.play(AssetSource('sounds/dialtone.mp3'));
      } else {
        await _audioPlayer.play(AssetSource('sounds/ringtone.mp3'));
      }
    } catch (e) {
      debugPrint("Error playing sound: $e");
    }
  }

  Future<void> stopRinging() async {
    await _audioPlayer.stop();
  }

  Future<void> joinChannel(String channelId, String token) async {
    if (_engine == null) await initEngine();
    
    String? myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    await _engine!.joinChannelWithUserAccount(
      token: token,
      channelId: channelId,
      userAccount: myUid,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        autoSubscribeAudio: true,
        publishMicrophoneTrack: true,
      ),
    );
  }

  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    await _engine?.muteLocalAudioStream(_isMuted);
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    _isSpeaker = !_isSpeaker;
    await _engine?.setEnableSpeakerphone(_isSpeaker);
    notifyListeners();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _engine?.release();
    _callDocSubscription?.cancel();
    super.dispose();
  }
}

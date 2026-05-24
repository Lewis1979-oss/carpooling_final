import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' as fln;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../main.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../screens/voice_call_screen.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final fln.FlutterLocalNotificationsPlugin _localNotificationsPlugin = fln.FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription? _notificationSubscription;

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const fln.AndroidNotificationChannel _channel = fln.AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: fln.Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  Future<void> init() async {
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      await uploadToken();
    }

    const initializationSettings = fln.InitializationSettings(
      android: fln.AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: fln.DarwinInitializationSettings(),
    );
    
    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (fln.NotificationResponse response) {
        _handleNotificationClick(response.payload);
      },
    );

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<fln.AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    FirebaseMessaging.onMessage.listen(_showRemoteNotification);
    
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      startListening(currentUser.uid);
    }

    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        startListening(user.uid);
      } else {
        stopListening();
      }
    });
  }

  void startListening(String userId) {
    _notificationSubscription?.cancel();
    final startTime = DateTime.now();

    _notificationSubscription = _db.collection('users').doc(userId).collection('notifications')
      .where('isRead', isEqualTo: false)
      .snapshots()
      .listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data != null) {
              final Timestamp? ts = data['timestamp'] as Timestamp?;
              if (ts == null || ts.toDate().isAfter(startTime.subtract(const Duration(seconds: 5)))) {
                
                final String? rideId = data['rideId'];
                
                // --- SPECIAL CALL LOGIC ---
                if (rideId != null && rideId.startsWith("CALL_")) {
                  _triggerIncomingCallUI(
                    channelId: rideId.replaceFirst("CALL_", ""),
                    callerId: data['callerId'] ?? "",
                    token: data['token'] ?? "", // Extract token
                  );
                } else {
                  showNotification(
                    title: data['title'] ?? 'New Message',
                    body: data['body'] ?? '',
                    payload: rideId,
                  );
                }
              }
              change.doc.reference.update({'isRead': true});
            }
          }
        }
      });
  }

  Future<void> _triggerIncomingCallUI({
    required String channelId, 
    required String callerId,
    required String token, // Required for security
  }) async {
    if (callerId.isEmpty) return;
    
    final callerData = await AuthService().getUserData(callerId);
    if (callerData != null && navigatorKey.currentState != null) {
      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => VoiceCallScreen(
            caller: callerData,
            channelId: channelId,
            token: token, // Pass the token to the screen
            isIncoming: true,
          ),
        ),
      );
    }
  }

  void _handleNotificationClick(String? payload) {
    if (payload == null) return;
    // Payload handling for background interaction
  }

  void stopListening() {
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
  }

  Future<void> sendNotificationToUser({
    required String targetUserId,
    required String title,
    required String body,
    String? rideId,
    String? callerId,
    String? token, // Added token field
  }) async {
    await _db.collection('users').doc(targetUserId).collection('notifications').add({
      'title': title,
      'body': body,
      'rideId': rideId,
      'callerId': callerId,
      'token': token, // Include token in the notification data
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> uploadToken() async {
    try {
      String? token = await _fcm.getToken();
      final user = FirebaseAuth.instance.currentUser;
      if (token != null && user != null) {
        await _db.collection('users').doc(user.uid).set({
          'fcmToken': token,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint("Token error: $e");
    }
  }

  Future<void> showNotification({required String title, required String body, String? payload}) async {
    await _localNotificationsPlugin.show(
      DateTime.now().millisecond,
      title,
      body,
      fln.NotificationDetails(
        android: fln.AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: fln.Importance.max,
          priority: fln.Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
        ),
        iOS: const fln.DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  void _showRemoteNotification(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    if (notification != null) {
      showNotification(
        title: notification.title ?? '',
        body: notification.body ?? '',
      );
    }
  }
}

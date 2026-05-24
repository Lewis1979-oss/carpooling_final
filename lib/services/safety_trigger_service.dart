import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'safety_service.dart';
import 'user_service.dart';
import '../config/safety_config.dart';

class SafetyTriggerService {
  final SpeechToText _speech = SpeechToText();
  final AudioRecorder _recorder = AudioRecorder();
  final SafetyService _safetyService = SafetyService();
  final UserService _userService = UserService();
  
  bool _isListening = false;
  String _safeWord = "send help"; 
  Timer? _volumeTimer;
  int _volumePressCount = 0;

  // Initialize background listening
  Future<void> init() async {
    await _initSpeech();
  }

  Future<void> _initSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (status) => print('Speech status: $status'),
      onError: (errorNotification) => print('Speech error: $errorNotification'),
    );
    if (available) {
      startListening();
    }
  }

  void startListening() {
    if (_isListening) return;
    _isListening = true;
    
    _speech.listen(
      onResult: (result) {
        String words = result.recognizedWords.toLowerCase();
        if (words.contains(_safeWord)) {
          triggerSOS("Voice Command: '$_safeWord' detected");
        }
      },
      listenFor: const Duration(hours: 1), 
      pauseFor: const Duration(seconds: 10),
      partialResults: true,
      cancelOnError: false,
      listenMode: ListenMode.deviceDefault,
    );
  }

  void handleVolumeButtonPress() {
    _volumePressCount++;
    _volumeTimer?.cancel();
    
    if (_volumePressCount >= 3) {
      _volumePressCount = 0;
      triggerSOS("Triple volume button press detected");
    } else {
      _volumeTimer = Timer(const Duration(seconds: 2), () {
        _volumePressCount = 0;
      });
    }
  }

  Future<void> triggerSOS(String reason) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    print("!!! SOS TRIGGERED: $reason !!!");

    // 1. Get Current Location for immediate SMS use
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (e) {
      print("Error getting location: $e");
    }

    // 2. Start Recording (10 seconds)
    File? audioFile = await _record10SecondClip();

    // 3. Report to Admin via SafetyService (Creates Dashboard Record)
    await _safetyService.reportIssue(
      null, 
      user.uid, 
      reason, 
      isSOS: true,
      audioFile: audioFile,
    );

    // 4. Notify Emergency Contact with Location Link (System SMS app)
    await _notifyEmergencyContact(user.uid, reason, position);

    // 5. Notify Admin via Twilio SMS (Background automated SMS)
    await _sendAdminTwilioSMS(user.uid, reason, position);
  }

  Future<void> _sendAdminTwilioSMS(String uid, String reason, Position? position) async {
    try {
      final userData = await _userService.getUserData(uid);
      String locText = "";
      if (position != null) {
        locText = "\nLocation: https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";
      }

      final String message = "URGENT SOS: ${userData?.name ?? 'User'} needs help!\nReason: $reason$locText";

      final String url = 'https://api.twilio.com/2010-04-01/Accounts/${SafetyConfig.twilioAccountSid}/Messages.json';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Basic ' + base64Encode(utf8.encode('${SafetyConfig.twilioAccountSid}:${SafetyConfig.twilioAuthToken}')),
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'From': SafetyConfig.twilioFromNumber,
          'To': SafetyConfig.adminEmergencyNumber,
          'Body': message,
        },
      );

      if (response.statusCode == 201) {
        print("Twilio SOS SMS sent successfully to Admin.");
      } else {
        print("Failed to send Twilio SMS: ${response.body}");
      }
    } catch (e) {
      print("Error sending Twilio SOS: $e");
    }
  }

  Future<void> _notifyEmergencyContact(String uid, String reason, Position? position) async {
    try {
      final userData = await _userService.getUserData(uid);
      final contact = userData?.emergencyContact;
      
      if (contact != null && contact.isNotEmpty) {
        String locText = "";
        if (position != null) {
          locText = " My live location: https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";
        }
        
        final String message = "EMERGENCY SOS from ${userData?.name}: $reason.$locText Please check on me!";
        final Uri smsUrl = Uri.parse("sms:$contact?body=${Uri.encodeComponent(message)}");
        
        if (await canLaunchUrl(smsUrl)) {
          await launchUrl(smsUrl);
        }
      }
    } catch (e) {
      print("Error notifying emergency contact: $e");
    }
  }

  Future<File?> _record10SecondClip() async {
    try {
      if (await _recorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/sos_clip.m4a';
        
        await _recorder.start(const RecordConfig(), path: path);
        await Future.delayed(const Duration(seconds: 10));
        
        final finalPath = await _recorder.stop();
        if (finalPath != null) {
          return File(finalPath);
        }
      }
    } catch (e) {
      print("Error recording SOS audio: $e");
    }
    return null;
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'safety_service.dart';
import 'user_service.dart';
import '../config/safety_config.dart';

class SafetyTriggerService {
  final SpeechToText _speech = SpeechToText();
  final SafetyService _safetyService = SafetyService();
  final UserService _userService = UserService();
  
  bool _isListening = false;
  String _safeWord = "send help"; 
  Timer? _volumeTimer;
  int _volumePressCount = 0;

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

    // 1. Get Current Location Immediately
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (e) {
      print("Error getting location: $e");
    }

    // 2. IMMEDIATE AUTOMATED ALERT (Twilio to Admin only)
    _sendAdminTwilioSMS(user.uid, reason, position);

    // 3. Report to Firestore (Admin Dashboard)
    await _safetyService.reportIssue(
      null, 
      user.uid, 
      reason, 
      isSOS: true,
      audioFile: null, // Audio recording removed as requested
    );
  }

  // Core Twilio SMS Logic
  Future<void> _sendTwilioSMS(String to, String message) async {
    try {
      final String url = 'https://api.twilio.com/2010-04-01/Accounts/${SafetyConfig.twilioAccountSid}/Messages.json';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Basic ' + base64Encode(utf8.encode('${SafetyConfig.twilioAccountSid}:${SafetyConfig.twilioAuthToken}')),
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'From': SafetyConfig.twilioFromNumber,
          'To': to,
          'Body': message,
        },
      );

      if (response.statusCode == 201) {
        print("Twilio SMS successfully sent to $to");
      } else {
        print("Twilio Error (${response.statusCode}): ${response.body}");
      }
    } catch (e) {
      print("Exception sending Twilio SMS: $e");
    }
  }

  Future<void> _sendAdminTwilioSMS(String uid, String reason, Position? position) async {
    final userData = await _userService.getUserData(uid);
    String locText = position != null 
        ? "\nLocation: https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}" 
        : "\nLocation: Unavailable";

    final String message = "URGENT SOS: ${userData?.name ?? 'A User'} needs help!\nReason: $reason$locText";
    await _sendTwilioSMS(SafetyConfig.adminEmergencyNumber, message);
  }
}

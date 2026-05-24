import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../models/safety_report_model.dart';
import '../config/safety_config.dart';

class SafetyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Submit a safety report or SOS with location and optional audio
  Future<void> reportIssue(
    String? rideId, 
    String reporterId, 
    String reason, {
    String? reportedUserId, // Track who is being reported
    bool isSOS = false,
    File? audioFile,
  }) async {
    try {
      // 1. Get Current Location
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
      } catch (e) {
        print("Could not get location for SOS: $e");
      }

      // 2. Upload Audio if exists
      String? audioUrl;
      if (audioFile != null) {
        final ref = _storage.ref().child('safety_audio').child('${DateTime.now().millisecondsSinceEpoch}.aac');
        await ref.putFile(audioFile);
        audioUrl = await ref.getDownloadURL();
      }

      // 3. Create Report
      final report = SafetyReportModel(
        id: '',
        rideId: rideId,
        reporterId: reporterId,
        reportedUserId: reportedUserId,
        reason: reason,
        timestamp: DateTime.now(),
        isSOS: isSOS,
        lat: position?.latitude,
        lng: position?.longitude,
        audioUrl: audioUrl,
      );

      await _db.collection('safety_reports').add(report.toMap());
      
      // 4. If it's an SOS, also send SMS to Admin via Twilio
      if (isSOS) {
        await sendAdminSOSViaTwilio(reporterId, reason, position);
      }
    } catch (e) {
      print("Error reporting issue: ${e.toString()}");
    }
  }

  // New method to send SMS via Twilio API
  Future<void> sendAdminSOSViaTwilio(String reporterId, String reason, Position? position) async {
    try {
      // Fetch reporter name for the message
      final userDoc = await _db.collection('users').doc(reporterId).get();
      final userName = userDoc.data()?['name'] ?? 'A User';
      
      String locText = "";
      if (position != null) {
        locText = "\nLocation: https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";
      }

      final String message = "URGENT SOS: $userName needs help!\nReason: $reason$locText";

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

  // Get all safety reports (for Admin)
  Stream<List<SafetyReportModel>> getSafetyReports() {
    return _db.collection('safety_reports')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SafetyReportModel.fromMap(doc.data(), doc.id)).toList());
  }

  // Fetch High Risk Zones from Firestore
  Future<void> fetchHighRiskZones() async {
    try {
      final snapshot = await _db.collection('high_risk_zones').get();
      SafetyConfig.highRiskZones = snapshot.docs
          .map((doc) => HighRiskZone.fromMap(doc.data()))
          .toList();
      print("Successfully loaded ${SafetyConfig.highRiskZones.length} high-risk zones.");
    } catch (e) {
      print("Error fetching high risk zones: $e");
    }
  }
}

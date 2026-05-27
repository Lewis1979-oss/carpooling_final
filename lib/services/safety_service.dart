import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
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
    String? reportedUserId, 
    bool isSOS = false,
    File? audioFile,
    Position? existingPosition, // Added to use location already fetched
  }) async {
    try {
      // 1. Use existing location or fetch new one if not provided
      Position? position = existingPosition;
      if (position == null) {
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 5),
          );
        } catch (e) {
          print("Could not get location for report: $e");
        }
      }

      // 2. Upload Audio if exists
      String? audioUrl;
      if (audioFile != null) {
        final ref = _storage.ref().child('safety_audio').child('${DateTime.now().millisecondsSinceEpoch}.aac');
        await ref.putFile(audioFile);
        audioUrl = await ref.getDownloadURL();
      }

      // 3. Create Report in Firestore (This updates the Admin Dashboard)
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
      print("SOS report successfully sent to Admin Dashboard.");
      
    } catch (e) {
      print("Error reporting issue to dashboard: ${e.toString()}");
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

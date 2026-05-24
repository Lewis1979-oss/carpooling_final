import 'package:cloud_firestore/cloud_firestore.dart';

class SafetyReportModel {
  final String id;
  final String? rideId;
  final String reporterId;
  final String? reportedUserId; // Added to track who is being reported
  final String reason;
  final DateTime timestamp;
  final bool isSOS;
  final double? lat;
  final double? lng;
  final String? audioUrl;

  SafetyReportModel({
    required this.id,
    this.rideId,
    required this.reporterId,
    this.reportedUserId,
    required this.reason,
    required this.timestamp,
    this.isSOS = false,
    this.lat,
    this.lng,
    this.audioUrl,
  });

  factory SafetyReportModel.fromMap(Map<String, dynamic> data, String documentId) {
    return SafetyReportModel(
      id: documentId,
      rideId: data['rideId'],
      reporterId: data['reporterId'] ?? '',
      reportedUserId: data['reportedUserId'],
      reason: data['reason'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isSOS: data['isSOS'] ?? false,
      lat: data['lat']?.toDouble(),
      lng: data['lng']?.toDouble(),
      audioUrl: data['audioUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (rideId != null) 'rideId': rideId,
      'reporterId': reporterId,
      if (reportedUserId != null) 'reportedUserId': reportedUserId,
      'reason': reason,
      'timestamp': Timestamp.fromDate(timestamp),
      'isSOS': isSOS,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (audioUrl != null) 'audioUrl': audioUrl,
    };
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

enum ActivityType { status, confirmation, receipt }

class ActivityModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final DateTime timestamp;
  final ActivityType type;
  final String? rideId;

  ActivityModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    this.rideId,
  });

  factory ActivityModel.fromMap(Map<String, dynamic> data, String documentId) {
    return ActivityModel(
      id: documentId,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      type: ActivityType.values.firstWhere(
        (e) => e.toString() == data['type'],
        orElse: () => ActivityType.status,
      ),
      rideId: data['rideId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type.toString(),
      'rideId': rideId,
    };
  }
}

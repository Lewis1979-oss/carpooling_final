import 'package:cloud_firestore/cloud_firestore.dart';

class RatingModel {
  final String id;
  final String rideId;
  final String reviewerId;
  final String revieweeId;
  final double rating;
  final String comment;
  final DateTime timestamp;

  RatingModel({
    required this.id,
    required this.rideId,
    required this.reviewerId,
    required this.revieweeId,
    required this.rating,
    required this.comment,
    required this.timestamp,
  });

  factory RatingModel.fromMap(Map<String, dynamic> data, String documentId) {
    return RatingModel(
      id: documentId,
      rideId: data['rideId'] ?? '',
      reviewerId: data['reviewerId'] ?? '',
      revieweeId: data['revieweeId'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      comment: data['comment'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rideId': rideId,
      'reviewerId': reviewerId,
      'revieweeId': revieweeId,
      'rating': rating,
      'comment': comment,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/rating_model.dart';
import '../models/user_model.dart';

class RatingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Check if a reviewer has already rated a reviewee for a specific ride
  Future<bool> hasAlreadyRated(String rideId, String reviewerId, String revieweeId) async {
    final query = await _db.collection('ratings')
        .where('rideId', isEqualTo: rideId)
        .where('reviewerId', isEqualTo: reviewerId)
        .where('revieweeId', isEqualTo: revieweeId)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  // Submit a rating and update the user's average rating
  Future<void> submitRating(RatingModel rating) async {
    try {
      // 0. Ensure user can only rate once per ride
      bool alreadyRated = await hasAlreadyRated(rating.rideId, rating.reviewerId, rating.revieweeId);
      if (alreadyRated) {
        throw Exception("You have already rated this user for this ride.");
      }

      // 1. Add the rating document
      await _db.collection('ratings').add(rating.toMap());

      // 2. Update the reviewee's stats
      final userRef = _db.collection('users').doc(rating.revieweeId);
      
      await _db.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userRef);
        
        if (!userSnapshot.exists) return;

        final userData = userSnapshot.data()!;
        final user = UserModel.fromMap(userData, userSnapshot.id);

        double currentTotalRating = (userData['totalRating'] ?? 0.0).toDouble();
        int currentCount = userData['ratingCount'] ?? 0;
        int currentPoints = userData['zedPoints'] ?? 0;

        double newTotalRating = currentTotalRating + rating.rating;
        int newCount = currentCount + 1;
        double newAverage = newTotalRating / newCount;
        
        // Reward points based on rating
        double baseRewardPoints = 0;
        if (rating.rating >= 4.5) {
          baseRewardPoints = 10;
        } else if (rating.rating >= 4.0) {
          baseRewardPoints = 5;
        }

        // Apply 1.2x multiplier if user has "Super Driver" badge
        if (user.badges.contains("Super Driver")) {
          baseRewardPoints *= 1.2;
        }

        transaction.update(userRef, {
          'totalRating': newTotalRating,
          'ratingCount': newCount,
          'averageRating': newAverage,
          'zedPoints': currentPoints + baseRewardPoints.toInt(),
        });
      });
    } catch (e) {
      print("Error submitting rating: ${e.toString()}");
      rethrow; // Rethrow to handle it in the UI
    }
  }

  // Get ratings for a specific user
  Stream<List<RatingModel>> getUserRatings(String userId) {
    return _db.collection('ratings')
        .where('revieweeId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => RatingModel.fromMap(doc.data(), doc.id)).toList());
  }
}

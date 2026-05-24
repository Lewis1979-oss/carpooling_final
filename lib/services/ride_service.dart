import 'dart:math' show Random, asin, cos, sqrt;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/ride_model.dart';
import '../models/user_model.dart';
import '../config/safety_config.dart';
import 'notification_service.dart';

class RideService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _notificationService = NotificationService();

  // Post a new ride
  Future<void> postRide(RideModel ride) async {
    try {
      // Check if it's a late-night ride and generate PIN if so
      String? pinCode;
      bool isLateNight = SafetyConfig.isTimeLateNight(ride.dateTime);
      
      if (isLateNight) {
        pinCode = (Random().nextInt(9000) + 1000).toString(); // Generate 4-digit PIN
      }

      final rideMap = ride.toMap();
      rideMap['pinCode'] = pinCode;
      rideMap['isLateNight'] = isLateNight;

      await _db.collection('rides').add(rideMap);
    } catch (e) {
      print("Post Ride Error: ${e.toString()}");
    }
  }

  // Verify PIN to start the ride
  Future<bool> verifyRidePin(String rideId, String enteredPin) async {
    try {
      final doc = await _db.collection('rides').doc(rideId).get();
      if (!doc.exists) return false;
      
      final ride = RideModel.fromMap(doc.data() as Map<String, dynamic>?, doc.id);
      if (ride.pinCode == enteredPin) {
        await updateRideStatus(rideId, 'ongoing');
        return true;
      }
      return false;
    } catch (e) {
      print("Verify PIN Error: $e");
      return false;
    }
  }

  // Get all available rides with filters
  Stream<List<RideModel>> getRides(UserModel currentUser) {
    return _db.collection('rides')
        .where('status', isEqualTo: 'upcoming')
        .snapshots()
        .map((snapshot) {
          try {
            return snapshot.docs.map((doc) => RideModel.fromMap(doc.data(), doc.id)).where((ride) {
              if (ride.deletedBy.contains(currentUser.id)) return false;
              
              // Verified Only Filter: Non-verified users cannot even see these rides
              if (ride.verifiedOnly && !currentUser.isVerified) return false;

              // Lady-Pool Filter: Only female passengers see female-only rides
              if (ride.ladiesOnly && currentUser.gender?.toLowerCase() != 'female') return false;

              return true;
            }).toList();
          } catch (e) {
            print("Error parsing rides: $e");
            return [];
          }
        });
  }

  // Hide ride for user (Soft delete from their history)
  Future<void> hideRideForUser(String rideId, String userId) async {
    try {
      await _db.collection('rides').doc(rideId).update({
        'deletedBy': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      print("Hide Ride Error: $e");
    }
  }

  // Join Waitlist with Security Check
  Future<void> joinWaitlist(String rideId, String userId) async {
    final rideDoc = await _db.collection('rides').doc(rideId).get();
    final ride = RideModel.fromMap(rideDoc.data() as Map<String, dynamic>?, rideDoc.id);
    final userDoc = await _db.collection('users').doc(userId).get();
    final user = UserModel.fromMap(userDoc.data()!, userDoc.id);

    // Enforce "Verified Only" rule at join time
    if (ride.verifiedOnly && !user.isVerified) throw Exception("Only ID-Verified users can join this ride.");

    await _db.collection('rides').doc(rideId).update({
      'waitlist': FieldValue.arrayUnion([userId]),
    });
  }

  // Cancel Participation
  Future<void> cancelParticipation(String rideId, String userId) async {
    final doc = await _db.collection('rides').doc(rideId).get();
    final ride = RideModel.fromMap(doc.data() as Map<String, dynamic>?, doc.id);

    bool wasFull = ride.availableSeats == 0;
    bool wasPassenger = ride.passengers.contains(userId);

    await _db.collection('rides').doc(rideId).update({
      'passengers': FieldValue.arrayRemove([userId]),
      'pendingPassengers': FieldValue.arrayRemove([userId]),
      'waitlist': FieldValue.arrayRemove([userId]),
      'availableSeats': wasPassenger ? FieldValue.increment(1) : FieldValue.increment(0),
    });

    // Notify Waitlist Priority (First Person)
    if (wasFull && wasPassenger && ride.waitlist.isNotEmpty) {
      final updatedDoc = await _db.collection('rides').doc(rideId).get();
      final updatedRide = RideModel.fromMap(updatedDoc.data() as Map<String, dynamic>?, rideId);

      if (updatedRide.waitlist.isNotEmpty) {
        String firstInLine = updatedRide.waitlist.first;
        await _notificationService.sendNotificationToUser(
          targetUserId: firstInLine,
          title: 'Seat Available!',
          body: 'A seat has opened up for the ride to ${ride.destination}. You are first on the waitlist!',
          rideId: rideId,
        );
      }
    }
  }

  // Update Ride Status
  Future<void> updateRideStatus(String rideId, String status) async {
    try {
      final doc = await _db.collection('rides').doc(rideId).get();
      final ride = RideModel.fromMap(doc.data() as Map<String, dynamic>?, doc.id);

      await _db.collection('rides').doc(rideId).update({'status': status});
      
      if (status == 'cancelled') {
        // Notify all passengers
        for (String pId in ride.passengers) {
          await _notificationService.sendNotificationToUser(
            targetUserId: pId,
            title: 'Ride Cancelled',
            body: 'The ride to ${ride.destination} was cancelled by the driver.',
            rideId: rideId,
          );
        }
      }

      if (status == 'completed') {
        await _processPoints(ride);
      }
    } catch (e) {
      print("Update Status Error: $e");
    }
  }

  Future<void> _processPoints(RideModel ride) async {
    // Process Points & Gold Member Badge Logic
    await _updateUserPoints(ride.driverId, 50);
    for (String pId in ride.passengers) {
      await _updateUserPoints(pId, 20);
    }
  }

  Future<void> _updateUserPoints(String userId, int points) async {
    final userRef = _db.collection('users').doc(userId);
    await _db.runTransaction((transaction) async {
      DocumentSnapshot snap = await transaction.get(userRef);
      if (!snap.exists) return;
      
      int currentPoints = (snap.data() as Map<String, dynamic>)['zedPoints'] ?? 0;
      int newTotal = currentPoints + points;
      List badges = List.from((snap.data() as Map<String, dynamic>)['badges'] ?? []);

      transaction.update(userRef, {'zedPoints': newTotal});

      // Gold Member Award (1000 Points)
      if (newTotal >= 1000 && !badges.contains('Gold Member')) {
        badges.add('Gold Member');
        transaction.update(userRef, {'badges': badges});
        _notificationService.sendNotificationToUser(
          targetUserId: userId,
          title: 'New Badge Unlocked!',
          body: 'Congratulations! You are now a Gold Member of ZedPool.',
        );
      }
    });
  }

  // Auto-Arrival Haversine Logic
  Future<void> updateLiveLocation(String rideId, double lat, double lng) async {
    final doc = await _db.collection('rides').doc(rideId).get();
    final ride = RideModel.fromMap(doc.data() as Map<String, dynamic>?, doc.id);

    await _db.collection('rides').doc(rideId).update({'currentLat': lat, 'currentLng': lng});

    for (String pId in ride.passengers) {
      if (_calculateDistance(lat, lng, ride.pickupLat, ride.pickupLng) <= 1.0) {
        await _notificationService.sendNotificationToUser(
          targetUserId: pId,
          title: 'Driver Arriving!',
          body: 'Your driver is 2 minutes away!',
          rideId: rideId,
        );
      }
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((lat2 - lat1) * p) / 2 + c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  // Passenger Join Request with Security Check
  Future<void> requestToJoin(String rideId, String userId) async {
    final rideDoc = await _db.collection('rides').doc(rideId).get();
    final ride = RideModel.fromMap(rideDoc.data() as Map<String, dynamic>?, rideDoc.id);
    final userDoc = await _db.collection('users').doc(userId).get();
    final user = UserModel.fromMap(userDoc.data()!, userDoc.id);

    if (ride.verifiedOnly && !user.isVerified) throw Exception("Join failed: Your ID must be verified by an Admin.");

    await _db.collection('rides').doc(rideId).update({
      'pendingPassengers': FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> approvePassenger(String rideId, String userId) async {
    await _db.collection('rides').doc(rideId).update({
      'pendingPassengers': FieldValue.arrayRemove([userId]),
      'passengers': FieldValue.arrayUnion([userId]),
      'availableSeats': FieldValue.increment(-1),
      'waitlist': FieldValue.arrayRemove([userId]),
    });
  }

  Future<void> rejectPassenger(String rideId, String userId) async {
    await _db.collection('rides').doc(rideId).update({
      'pendingPassengers': FieldValue.arrayRemove([userId]),
    });
  }

  Stream<List<RideModel>> getRidesByDriver(String driverId) {
    return _db.collection('rides').where('driverId', isEqualTo: driverId).snapshots().map((snapshot) => snapshot.docs.map((doc) => RideModel.fromMap(doc.data(), doc.id)).toList());
  }

  Stream<List<RideModel>> getRidesByPassenger(String userId) {
    return _db.collection('rides').snapshots().map((snapshot) => snapshot.docs.map((doc) => RideModel.fromMap(doc.data(), doc.id)).where((ride) => (ride.passengers.contains(userId) || ride.pendingPassengers.contains(userId) || ride.waitlist.contains(userId)) && !ride.deletedBy.contains(userId)).toList());
  }

  Stream<RideModel> getRideById(String rideId) {
    return _db.collection('rides').doc(rideId).snapshots().map((doc) => RideModel.fromMap(doc.data() as Map<String, dynamic>?, doc.id));
  }
}

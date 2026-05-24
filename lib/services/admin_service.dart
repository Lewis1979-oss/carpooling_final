import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/ride_model.dart';
import '../models/user_model.dart';
import '../models/chat_model.dart';
import 'chat_service.dart';

class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ChatService _chatService = ChatService();

  // Track all rides in the system
  Stream<List<RideModel>> getAllRides() {
    return _db.collection('rides').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => RideModel.fromMap(doc.data(), doc.id)).toList());
  }

  // Track all registered users
  Stream<List<UserModel>> getAllUsers() {
    return _db.collection('users').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList());
  }

  // Monitor chat messages for a specific ride (Safety Check)
  Stream<QuerySnapshot> getRideChatLogs(String rideId) {
    return _db.collection('rides').doc(rideId).collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Add badge to user
  Future<void> addBadgeToUser(String userId, String badge) async {
    await _db.collection('users').doc(userId).update({
      'badges': FieldValue.arrayUnion([badge])
    });
  }

  // Remove badge from user
  Future<void> removeBadgeFromUser(String userId, String badge) async {
    await _db.collection('users').doc(userId).update({
      'badges': FieldValue.arrayRemove([badge])
    });
  }

  // Update User Identity Verification Status
  Future<void> updateVerificationStatus(String userId, String status) async {
    await _db.collection('users').doc(userId).update({
      'verificationStatus': status,
      'isVerified': status == 'verified',
    });

    if (status == 'verified') {
      await _sendAdminAutomatedMessage(userId, 'Congratulations! Your Identity Verification (Driver\'s License) has been approved. You are now a verified member of ZedPool.');
    } else if (status == 'rejected') {
      await _sendAdminAutomatedMessage(userId, 'Your Identity Verification request was declined. Please ensure your documents are clear and valid, then try again.');
    }
  }

  // Update Vehicle Verification Status
  Future<void> updateVehicleVerificationStatus(String userId, String status) async {
    await _db.collection('users').doc(userId).update({
      'vehicleVerificationStatus': status,
    });

    if (status == 'verified') {
      await _sendAdminAutomatedMessage(userId, 'Great news! Your Vehicle Verification has been approved. Your car is now authorized for rides on ZedPool.');
    } else if (status == 'rejected') {
      await _sendAdminAutomatedMessage(userId, 'Your Vehicle Verification request was declined. Please re-upload a clear photo of your vehicle showing the license plate.');
    }
  }

  // Set User Block Status
  Future<void> setUserBlockStatus(String userId, bool isBlocked) async {
    await _db.collection('users').doc(userId).update({
      'isBlocked': isBlocked,
    });
    
    final message = isBlocked 
      ? 'Your account has been suspended by the administrator for safety or policy violations. Please contact support if you believe this is an error.' 
      : 'Your account has been reactivated. You can now use ZedPool services again.';
      
    await _sendAdminAutomatedMessage(userId, message);
  }

  Future<void> _sendAdminAutomatedMessage(String userId, String text) async {
    try {
      final adminId = FirebaseAuth.instance.currentUser?.uid;
      if (adminId == null) return;

      final chatId = _chatService.getPrivateChatId(adminId, userId);
      
      await _chatService.sendPrivateMessage(
        chatId,
        MessageModel(
          id: '',
          senderId: adminId,
          senderName: 'ZedPool',
          text: text,
          timestamp: DateTime.now(),
        ),
        userId,
      );
    } catch (e) {
      print("Error sending admin automated message: $e");
    }
  }
}

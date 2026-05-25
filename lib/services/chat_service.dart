import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/chat_model.dart';
import '../models/ride_model.dart';
import 'notification_service.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _notificationService = NotificationService();

  // Upload File (Image or Voice) to Firebase Storage
  Future<String?> uploadFile(String path, String folder) async {
    try {
      File file = File(path);
      String fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.split('/').last}';
      Reference ref = _storage.ref().child(folder).child(fileName);
      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Error uploading file: $e");
      return null;
    }
  }

  // Send a group message
  Future<void> sendMessage(String rideId, MessageModel message) async {
    try {
      // Create message with 'delivered' status as it hits the database
      final msgMap = message.toMap();
      msgMap['status'] = MessageStatus.delivered.name;

      await _db.collection('rides').doc(rideId).collection('messages').add(msgMap);
      
      String displayMsg = message.isImage ? '📷 Image' : (message.isVoice ? '🎤 Voice Message' : message.text);
      
      await _db.collection('rides').doc(rideId).update({
        'lastMessage': '${message.senderName}: $displayMsg',
        'lastSenderId': message.senderId,
        'lastTimestamp': Timestamp.fromDate(message.timestamp),
      });

      final rideDoc = await _db.collection('rides').doc(rideId).get();
      if (rideDoc.exists) {
        final data = rideDoc.data();
        if (data != null) {
          final ride = RideModel.fromMap(data, rideDoc.id);
          final allParticipants = {ride.driverId, ...ride.passengers};
          for (String userId in allParticipants) {
            if (userId != message.senderId) {
              await _notificationService.sendNotificationToUser(
                targetUserId: userId,
                title: 'Group Message: ${message.senderName}',
                body: displayMsg,
                rideId: rideId,
              );
            }
          }
        }
      }
    } catch (e) {
      print("Error sending group message: $e");
    }
  }

  // Generate a unique ID for a private chat between two users
  String getPrivateChatId(String uid1, String uid2) {
    List<String> ids = [uid1, uid2];
    ids.sort(); 
    return ids.join('_');
  }

  // Send a private message
  Future<void> sendPrivateMessage(String chatId, MessageModel message, String recipientId, {String? rideId}) async {
    try {
      // Create message with 'delivered' status as it hits the database
      final msgMap = message.toMap();
      msgMap['status'] = MessageStatus.delivered.name;

      await _db.collection('private_chats').doc(chatId).collection('messages').add(msgMap);
      
      String displayMsg = message.isImage ? '📷 Image' : (message.isVoice ? '🎤 Voice Message' : message.text);
      
      Map<String, dynamic> updateData = {
        'lastMessage': displayMsg,
        'lastSenderId': message.senderId,
        'lastTimestamp': Timestamp.fromDate(message.timestamp),
        'participants': chatId.split('_'),
      };
      if (rideId != null && rideId.isNotEmpty) updateData['rideId'] = rideId;
      await _db.collection('private_chats').doc(chatId).set(updateData, SetOptions(merge: true));

      await _notificationService.sendNotificationToUser(
        targetUserId: recipientId,
        title: 'Message from ${message.senderName}',
        body: displayMsg,
        rideId: rideId,
      );
    } catch (e) {
      print("Error sending private message: $e");
    }
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String? rideId, String? privateChatId, String currentUserId) async {
    try {
      Query query;
      if (privateChatId != null) {
        query = _db.collection('private_chats').doc(privateChatId).collection('messages');
      } else if (rideId != null && rideId.isNotEmpty) {
        query = _db.collection('rides').doc(rideId).collection('messages');
      } else {
        return;
      }

      final snapshot = await query.where('senderId', isNotEqualTo: currentUserId).get();
      WriteBatch batch = _db.batch();
      bool hasUpdates = false;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['status'] != 'read') {
          batch.update(doc.reference, {'status': 'read'});
          hasUpdates = true;
        }
      }

      if (hasUpdates) {
        await batch.commit();
      }
    } catch (e) {
      print("Error marking messages as read: $e");
    }
  }

  Stream<List<MessageModel>> getMessages(String rideId, String userId) {
    return _db.collection('rides').doc(rideId).collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            try {
              return MessageModel.fromMap(doc.data(), doc.id);
            } catch (e) {
              print("Error parsing group message ${doc.id}: $e");
              return null;
            }
          }).whereType<MessageModel>()
            .where((msg) => !msg.deletedBy.contains(userId))
            .toList();
        });
  }

  Stream<List<MessageModel>> getPrivateMessages(String chatId, String userId) {
    return _db.collection('private_chats').doc(chatId).collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            try {
              return MessageModel.fromMap(doc.data(), doc.id);
            } catch (e) {
              print("Error parsing private message ${doc.id}: $e");
              return null;
            }
          }).whereType<MessageModel>()
            .where((msg) => !msg.deletedBy.contains(userId))
            .toList();
        });
  }

  // Soft-Delete a private chat for a specific user
  Future<void> hidePrivateChatForUser(String chatId, String userId) async {
    try {
      await _db.collection('private_chats').doc(chatId).update({
        'hiddenBy': FieldValue.arrayUnion([userId])
      });
    } catch (e) {
      print("Hide Private Chat Error: $e");
    }
  }

  // Typing status
  Future<void> updateTypingStatus(String chatId, String userId, bool isTyping) async {
    try {
      await _db.collection('private_chats').doc(chatId).update({
        'typing.$userId': isTyping,
      });
    } catch (e) {
      print("Update typing status error: $e");
    }
  }

  Stream<bool> getTypingStatus(String chatId, String otherUserId) {
    return _db.collection('private_chats').doc(chatId).snapshots().map((doc) {
      if (!doc.exists) return false;
      final data = doc.data();
      final typing = data?['typing'] as Map?;
      return typing?[otherUserId] ?? false;
    });
  }

  // Reactions
  Future<void> addReaction({
    String? rideId,
    String? privateChatId,
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    try {
      DocumentReference docRef;
      if (privateChatId != null) {
        docRef = _db.collection('private_chats').doc(privateChatId).collection('messages').doc(messageId);
      } else if (rideId != null) {
        docRef = _db.collection('rides').doc(rideId).collection('messages').doc(messageId);
      } else {
        return;
      }
      await docRef.update({'reactions.$userId': emoji});
    } catch (e) {
      print("Add reaction error: $e");
    }
  }

  Future<void> deleteMessageForMe({
    required String? rideId,
    required String? privateChatId,
    required String messageId,
    required String userId,
  }) async {
    try {
      DocumentReference docRef;
      if (privateChatId != null) {
        docRef = _db.collection('private_chats').doc(privateChatId).collection('messages').doc(messageId);
      } else if (rideId != null) {
        docRef = _db.collection('rides').doc(rideId).collection('messages').doc(messageId);
      } else {
        return;
      }

      await docRef.update({
        'deletedBy': FieldValue.arrayUnion([userId])
      });
    } catch (e) {
      print("Delete message error: $e");
    }
  }
}

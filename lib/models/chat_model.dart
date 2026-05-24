import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageStatus { sent, delivered, read }

class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final String text;
  final DateTime timestamp;
  final List<String> deletedBy;
  final String? voiceUrl;
  final int? voiceDuration; // Duration in seconds
  final String? imageUrl;
  final bool isVoice;
  final bool isImage;
  final MessageStatus status;
  final String? replyToId;
  final String? replyToText;
  final Map<String, String> reactions;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    required this.text,
    required this.timestamp,
    this.deletedBy = const [],
    this.voiceUrl,
    this.voiceDuration,
    this.imageUrl,
    this.isVoice = false,
    this.isImage = false,
    this.status = MessageStatus.sent,
    this.replyToId,
    this.replyToText,
    this.reactions = const {},
  });

  factory MessageModel.fromMap(Map<String, dynamic> data, String documentId) {
    DateTime timestamp;
    try {
      if (data['timestamp'] is Timestamp) {
        timestamp = (data['timestamp'] as Timestamp).toDate();
      } else if (data['timestamp'] is String) {
        timestamp = DateTime.tryParse(data['timestamp']) ?? DateTime.now();
      } else {
        timestamp = DateTime.now();
      }
    } catch (e) {
      timestamp = DateTime.now();
    }

    return MessageModel(
      id: documentId,
      senderId: data['senderId']?.toString() ?? '',
      senderName: data['senderName']?.toString() ?? 'User',
      senderPhotoUrl: data['senderPhotoUrl']?.toString(),
      text: data['text']?.toString() ?? '',
      timestamp: timestamp,
      deletedBy: data['deletedBy'] != null ? List<String>.from(data['deletedBy']) : const [],
      voiceUrl: data['voiceUrl']?.toString(),
      voiceDuration: data['voiceDuration'] is int ? data['voiceDuration'] : null,
      imageUrl: data['imageUrl']?.toString(),
      isVoice: data['isVoice'] == true,
      isImage: data['isImage'] == true,
      status: MessageStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'sent'),
        orElse: () => MessageStatus.sent,
      ),
      replyToId: data['replyToId']?.toString(),
      replyToText: data['replyToText']?.toString(),
      reactions: data['reactions'] != null ? Map<String, String>.from(data['reactions']) : const {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'deletedBy': deletedBy,
      'voiceUrl': voiceUrl,
      'voiceDuration': voiceDuration,
      'isVoice': isVoice,
      'imageUrl': imageUrl,
      'isImage': isImage,
      'status': status.name,
      'replyToId': replyToId,
      'replyToText': replyToText,
      'reactions': reactions,
    };
  }
}

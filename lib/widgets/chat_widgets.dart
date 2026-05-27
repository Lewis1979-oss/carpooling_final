import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/chat_model.dart';
import 'glass_widgets.dart';

class ChatBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool isDark;
  final Color gold;
  final VoidCallback onLongPress;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.isDark,
    required this.gold,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Text(
                  message.senderName,
                  style: TextStyle(color: gold, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe 
                  ? gold.withOpacity(0.9) 
                  : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 0),
                  bottomRight: Radius.circular(isMe ? 0 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.isImage && message.imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(message.imageUrl!, fit: BoxFit.cover),
                    ),
                  if (message.text.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: message.isImage ? 8.0 : 0.0),
                      child: Text(
                        message.text,
                        style: TextStyle(
                          color: isMe ? Colors.black : (isDark ? Colors.white : Colors.black87),
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('hh:mm a').format(message.timestamp),
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.status == MessageStatus.read ? Icons.done_all : Icons.done,
                      size: 12,
                      color: message.status == MessageStatus.read ? Colors.blue : Colors.grey,
                    ),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReactionPickerSheet extends StatelessWidget {
  final Function(String) onEmojiSelected;

  const ReactionPickerSheet({super.key, required this.onEmojiSelected});

  @override
  Widget build(BuildContext context) {
    final List<String> reactions = ['❤️', '👍', '😂', '😮', '😢', '🔥'];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: reactions.map((emoji) => GestureDetector(
          onTap: () => onEmojiSelected(emoji),
          child: Text(emoji, style: const TextStyle(fontSize: 30)),
        )).toList(),
      ),
    );
  }
}

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../models/ride_model.dart';
import '../models/chat_model.dart';
import '../models/user_model.dart';
import '../services/ride_service.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../services/voice_call_service.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/chat_widgets.dart';
import 'voice_call_screen.dart';

class ChatScreen extends StatefulWidget {
  final String rideId;
  final String destinationName;
  final String? privateChatId;
  final String? otherUserName;
  final String? otherUserPhotoUrl;

  const ChatScreen({
    super.key,
    required this.rideId,
    required this.destinationName,
    this.privateChatId,
    this.otherUserName,
    this.otherUserPhotoUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final RideService _rideService = RideService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  
  bool _isEmojiVisible = false;
  FocusNode focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        setState(() => _isEmojiVisible = false);
      }
    });
    
    // Mark messages as read when entering
    _markAsRead();
  }

  void _markAsRead() {
    if (_currentUserId == null) return;
    if (widget.privateChatId != null) {
      _chatService.markPrivateMessagesAsRead(widget.privateChatId!, _currentUserId!);
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty || _currentUserId == null) return;

    final message = MessageModel(
      id: '',
      senderId: _currentUserId!,
      senderName: FirebaseAuth.instance.currentUser?.displayName ?? 'User',
      text: _messageController.text.trim(),
      timestamp: DateTime.now(),
    );

    if (widget.privateChatId != null) {
      // Find recipient ID from channel ID or pass it explicitly
      final otherId = widget.privateChatId!.replaceFirst(_currentUserId!, '').replaceFirst('_', '');
      _chatService.sendPrivateMessage(widget.privateChatId!, message, otherId);
    } else {
      _chatService.sendGroupMessage(widget.rideId, message);
    }

    _messageController.clear();
    _scrollToBottom();
  }

  void _sendImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile != null && _currentUserId != null) {
      final file = File(pickedFile.path);
      
      if (widget.privateChatId != null) {
        final otherId = widget.privateChatId!.replaceFirst(_currentUserId!, '').replaceFirst('_', '');
        await _chatService.sendPrivateImage(widget.privateChatId!, file, _currentUserId!, 
          FirebaseAuth.instance.currentUser?.displayName ?? 'User', otherId);
      } else {
        await _chatService.sendGroupImage(widget.rideId, file, _currentUserId!, 
          FirebaseAuth.instance.currentUser?.displayName ?? 'User');
      }
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    _messageController.text = _messageController.text + emoji.emoji;
  }

  void _showReactionPicker(MessageModel message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ReactionPickerSheet(
        onEmojiSelected: (emoji) {
          _addReaction(message, emoji);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _addReaction(MessageModel message, String emoji) {
    if (_currentUserId != null) {
      _chatService.addReaction(
        rideId: widget.privateChatId == null ? widget.rideId : null,
        privateChatId: widget.privateChatId,
        messageId: message.id,
        userId: _currentUserId!,
        emoji: emoji,
      );
    }
  }

  void _callUser(UserModel user) {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final callService = Provider.of<VoiceCallService>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => CallChoiceDialog(
        otherUser: user,
        gold: themeService.goldAccent,
        isDark: themeService.isDarkMode,
        onZedPoolCall: () {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser == null) return;

          // 1. Close dialog immediately
          Navigator.pop(context);

          // 2. Start the call in background
          final channelId = callService.getChannelId(currentUser.uid, user.id);
          callService.makeCall(receiver: user);

          // 3. Navigate to call screen immediately
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VoiceCallScreen(
                caller: user,
                channelId: channelId,
                token: "",
                isIncoming: false,
              ),
            ),
          );
        },
        onCellularCall: () async {
          if (user.phone != null) {
            final Uri tel = Uri(scheme: 'tel', path: user.phone);
            if (await canLaunchUrl(tel)) await launchUrl(tel);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;
    final activeGold = themeService.goldAccent;

    return StreamBuilder<RideModel?>(
      stream: widget.rideId.isNotEmpty ? _rideService.getRideById(widget.rideId) : Stream.value(null),
      builder: (context, rideSnapshot) {
        final ride = rideSnapshot.data;
        
        return GlassScaffold(
          appBar: AppBar(
            title: Column(
              children: [
                Text(
                  widget.privateChatId != null ? (widget.otherUserName ?? "Chat") : (ride?.destination.split(',').first ?? widget.destinationName),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                if (widget.privateChatId == null && ride != null)
                  Text(
                    '${ride.passengers.length + 1} participants',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
            actions: [
              if (widget.privateChatId != null)
                FutureBuilder<UserModel?>(
                  future: AuthService().getUserData(widget.privateChatId!.replaceFirst(_currentUserId!, '').replaceFirst('_', '')),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      return IconButton(
                        icon: Icon(Icons.call_outlined, color: activeGold),
                        onPressed: () => _callUser(snapshot.data!),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () {
                  if (ride != null) {
                    // Show ride info
                  }
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<MessageModel>>(
                  stream: widget.privateChatId != null 
                    ? _chatService.getPrivateMessages(widget.privateChatId!)
                    : _chatService.getGroupMessages(widget.rideId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final messages = snapshot.data ?? [];
                    
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = message.senderId == _currentUserId;
                        
                        return ChatBubble(
                          message: message,
                          isMe: isMe,
                          isDark: isDark,
                          gold: activeGold,
                          onLongPress: () => _showReactionPicker(message),
                        );
                      },
                    );
                  },
                ),
              ),
              if (_isEmojiVisible) 
                SizedBox(
                  height: 250,
                  child: EmojiPicker(
                    onEmojiSelected: _onEmojiSelected,
                    config: Config(
                      columns: 7,
                      emojiSizeMax: 32,
                      verticalSpacing: 0,
                      horizontalSpacing: 0,
                      gridPadding: EdgeInsets.zero,
                      initCategory: Category.RECENT,
                      bgColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                      indicatorColor: activeGold,
                      iconColor: Colors.grey,
                      iconColorSelected: activeGold,
                      backspaceColor: activeGold,
                      skinToneDialogBgColor: Colors.white,
                      skinToneIndicatorColor: Colors.grey,
                      enableSkinTones: true,
                      recentTabBehavior: RecentTabBehavior.RECENT,
                      recentsLimit: 28,
                      noRecents: const Text('No Recents', style: TextStyle(fontSize: 20, color: Colors.black26), textAlign: TextAlign.center),
                      loadingIndicator: const SizedBox.shrink(),
                      tabBarIndicatorSize: TabBarIndicatorSize.label,
                      categoryIcons: const CategoryIcons(),
                      buttonMode: ButtonMode.MATERIAL,
                    ),
                  ),
                ),
              _buildMessageInput(isDark, activeGold),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageInput(bool isDark, Color gold) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.5),
        border: Border(top: BorderSide(color: gold.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.emoji_emotions_outlined, color: _isEmojiVisible ? gold : Colors.grey),
            onPressed: () {
              setState(() => _isEmojiVisible = !_isEmojiVisible);
              if (_isEmojiVisible) focusNode.unfocus();
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_a_photo_outlined, color: Colors.grey),
            onPressed: _sendImage,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: focusNode,
              maxLines: null,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send, color: gold),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}

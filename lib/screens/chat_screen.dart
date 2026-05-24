import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/chat_model.dart';
import '../models/ride_model.dart';
import '../models/user_model.dart';
import '../services/chat_service.dart';
import '../services/ride_service.dart';
import '../services/auth_service.dart';
import '../services/safety_service.dart';
import '../services/theme_service.dart';
import '../services/voice_call_service.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/call_choice_dialog.dart';
import '../widgets/profile_preview_widgets.dart';
import '../widgets/voice_message_bubble.dart';
import '../widgets/image_picker_sheet.dart';
import 'payment_screen.dart';
import 'rating_dialog.dart';
import 'live_tracking_screen.dart';
import 'user_profile_view_screen.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String rideId;
  final String destinationName;
  final String? privateChatId; 
  final String? otherUserName; 
  final String? otherUserPhotoUrl;
  final bool isWithAdmin;

  const ChatScreen({
    super.key, 
    required this.rideId, 
    required this.destinationName,
    this.privateChatId,
    this.otherUserName,
    this.otherUserPhotoUrl,
    this.isWithAdmin = false,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final SafetyService _safetyService = SafetyService();
  final RideService _rideService = RideService();
  final AuthService _authService = AuthService();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  UserModel? _currentUserData;
  
  bool _isRecording = false;
  MessageModel? _replyingTo;
  bool _isTyping = false;
  Timer? _typingTimer;
  bool _isUploading = false;
  
  DateTime? _recordStartTime;
  int _currentRecordDuration = 0;
  Timer? _recordTimer;

  final String emergencyPhoneNumber = "+260964256282";

  final List<String> _quickReplies = [
    "I'm on my way!",
    "Running late, sorry.",
    "Where exactly are you?",
    "Okay, see you soon.",
    "Ready!",
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
    _markRead();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _typingTimer?.cancel();
    _recordTimer?.cancel();
    _setTypingStatus(false);
    _messageController.dispose();
    super.dispose();
  }

  void _markRead() {
    if (_currentUserId != null) {
      _chatService.markMessagesAsRead(widget.rideId.isEmpty ? null : widget.rideId, widget.privateChatId, _currentUserId!);
    }
  }

  Future<void> _loadCurrentUserData() async {
    if (_currentUserId != null) {
      final data = await _authService.getUserData(_currentUserId!);
      if (mounted) {
        setState(() => _currentUserData = data);
      }
    }
  }

  void _setTypingStatus(bool typing) {
    if (_currentUserId == null || widget.privateChatId == null) return;
    _chatService.updateTypingStatus(widget.privateChatId!, _currentUserId!, typing);
  }

  void _onTextChanged(String value) {
    if (!_isTyping && value.isNotEmpty) {
      setState(() => _isTyping = true);
      _setTypingStatus(true);
    }
    
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        if (mounted) setState(() => _isTyping = false);
        _setTypingStatus(false);
      }
    });
  }

  Future<void> _sendMessage({String? text, String? imageUrl, String? voiceUrl, int? voiceDuration}) async {
    final messageText = text ?? _messageController.text.trim();
    if ((messageText.isNotEmpty || imageUrl != null || voiceUrl != null) && _currentUserId != null) {
      
      setState(() => _isUploading = true);

      try {
        String? remoteImageUrl;
        String? remoteVoiceUrl;

        if (imageUrl != null) {
          remoteImageUrl = await _chatService.uploadFile(imageUrl, 'chat_images');
          if (remoteImageUrl == null) {
             _showError('Failed to upload image.');
             setState(() => _isUploading = false);
             return;
          }
        }
        if (voiceUrl != null) {
          remoteVoiceUrl = await _chatService.uploadFile(voiceUrl, 'chat_voices');
          if (remoteVoiceUrl == null) {
             _showError('Failed to upload voice message.');
             setState(() => _isUploading = false);
             return;
          }
        }

        final isAdmin = _currentUserData?.role == 'admin';

        final message = MessageModel(
          id: '', 
          senderId: _currentUserId!,
          senderName: isAdmin ? 'ZedPool' : (_currentUserData?.name ?? 'User'),
          senderPhotoUrl: isAdmin ? null : _currentUserData?.profilePic,
          text: messageText,
          timestamp: DateTime.now(),
          deletedBy: [],
          imageUrl: remoteImageUrl,
          voiceUrl: remoteVoiceUrl,
          voiceDuration: voiceDuration,
          isImage: remoteImageUrl != null,
          isVoice: remoteVoiceUrl != null,
          replyToId: _replyingTo?.id,
          replyToText: _replyingTo?.text,
        );
        
        if (widget.privateChatId != null) {
          final parts = widget.privateChatId!.split('_');
          final recipientId = parts.firstWhere((id) => id != _currentUserId, orElse: () => parts.first);
          await _chatService.sendPrivateMessage(widget.privateChatId!, message, recipientId, rideId: widget.rideId);
        } else {
          await _chatService.sendMessage(widget.rideId, message);
        }
        
        if (text == null && imageUrl == null && voiceUrl == null) _messageController.clear();
        if (mounted) setState(() => _replyingTo = null);
        _setTypingStatus(false);
      } catch (e) {
        _showError('Error sending message: $e');
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
  }

  void _showImageSourceAction() {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    ImagePickerSheet.show(
      context,
      gold: themeService.goldAccent,
      isDark: themeService.isDarkMode,
      onSourceSelected: (source) => _pickImage(source),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile != null) {
      _sendMessage(imageUrl: pickedFile.path); 
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() {
          _isRecording = true;
          _recordStartTime = DateTime.now();
          _currentRecordDuration = 0;
        });
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() => _currentRecordDuration++);
        });
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    final path = await _audioRecorder.stop();
    final duration = _currentRecordDuration;
    
    setState(() {
      _isRecording = false;
      _currentRecordDuration = 0;
    });

    if (path != null && duration > 0) {
      _sendMessage(voiceUrl: path, voiceDuration: duration);
    }
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
    showDialog(
      context: context,
      builder: (context) => CallChoiceDialog(
        otherUser: user,
        gold: themeService.goldAccent,
        isDark: themeService.isDarkMode,
        onZedPoolCall: () async {
          final callService = Provider.of<VoiceCallService>(context, listen: false);
          await callService.makeCall(receiver: user);
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
        final bool isPrivate = widget.privateChatId != null;

        return GlassScaffold(
          body: Column(
            children: [
              const SizedBox(height: 60),
              _buildAppBar(isDark, activeGold, isPrivate, ride, themeService),
              Expanded(
                child: StreamBuilder<List<MessageModel>>(
                  stream: isPrivate 
                      ? _chatService.getPrivateMessages(widget.privateChatId!, _currentUserId ?? '')
                      : _chatService.getMessages(widget.rideId, _currentUserId ?? ''),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    final messages = snapshot.data ?? [];
                    if (messages.isEmpty && !_isUploading) return _buildEmptyState(activeGold);
                    
                    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());

                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      physics: const BouncingScrollPhysics(),
                      itemCount: messages.length + (_isUploading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_isUploading && index == 0) {
                          return _buildUploadingIndicator(activeGold);
                        }
                        
                        final messageIndex = _isUploading ? index - 1 : index;
                        final message = messages[messageIndex];
                        final isMe = message.senderId == _currentUserId;
                        
                        bool showDateHeader = false;
                        if (messageIndex == messages.length - 1) {
                          showDateHeader = true;
                        } else {
                          final prevMessage = messages[messageIndex + 1];
                          if (message.timestamp.day != prevMessage.timestamp.day) showDateHeader = true;
                        }

                        return Column(
                          children: [
                            if (showDateHeader) _buildDateHeader(message.timestamp, isDark, activeGold),
                            _buildMessageBubble(message, isMe, isDark, activeGold, isPrivate),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              if (_replyingTo != null) _buildReplyPreview(isDark, activeGold),
              _buildQuickReplies(isDark, activeGold),
              _buildMessageInput(isDark, activeGold),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUploadingIndicator(Color gold) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: gold.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 12, height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                ),
                const SizedBox(width: 8),
                Text('Sending...', style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.7), fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(bool isDark, Color gold, bool isPrivate, RideModel? ride, ThemeService theme) {
    String otherUserId = "";
    if (isPrivate && widget.privateChatId != null) {
      otherUserId = widget.privateChatId!.split('_').firstWhere((id) => id != _currentUserId, orElse: () => "");
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Row(
        children: [
          IconButton(icon: Icon(Icons.arrow_back_ios, color: gold, size: 20), onPressed: () => Navigator.pop(context)),
          GestureDetector(
            onTap: () async {
              if (isPrivate && otherUserId.isNotEmpty && !widget.isWithAdmin) {
                final otherUser = await _authService.getUserData(otherUserId);
                if (otherUser != null && mounted) {
                  showProfilePreview(
                    context,
                    user: otherUser,
                    currentUserId: _currentUserId ?? '',
                    heroTag: 'chat_header_${otherUser.id}',
                  );
                }
              }
            },
            child: Hero(
              tag: isPrivate ? 'chat_header_$otherUserId' : 'group_header_${widget.rideId}',
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: gold.withOpacity(0.5), width: 1.5),
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: gold.withOpacity(0.1),
                  backgroundImage: widget.isWithAdmin 
                      ? const AssetImage('assets/icon/app_icon.png') as ImageProvider
                      : ((isPrivate && widget.otherUserPhotoUrl != null) ? NetworkImage(widget.otherUserPhotoUrl!) : null),
                  child: (isPrivate && widget.otherUserPhotoUrl == null && !widget.isWithAdmin) ? Icon(Icons.person, color: gold, size: 20) : (!isPrivate ? Icon(Icons.group, color: gold, size: 20) : null),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isWithAdmin ? 'ZedPool Support' : (isPrivate ? (widget.otherUserName ?? 'Chat') : (ride?.destination ?? widget.destinationName)),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                if (isPrivate && otherUserId.isNotEmpty && !widget.isWithAdmin)
                  StreamBuilder<UserModel?>(
                    stream: _authService.getUserStream(otherUserId),
                    builder: (context, snapshot) {
                      final user = snapshot.data;
                      if (user == null) return const SizedBox.shrink();
                      
                      return StreamBuilder<bool>(
                        stream: _chatService.getTypingStatus(widget.privateChatId!, otherUserId),
                        builder: (context, typingSnap) {
                          if (typingSnap.data == true) {
                            return Text('typing...', style: TextStyle(color: gold, fontSize: 11, fontWeight: FontWeight.bold));
                          }
                          
                          if (user.isOnline) {
                            return const Text('Online', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold));
                          }
                          
                          if (user.lastSeen != null) {
                            final lastSeenStr = _formatLastSeen(user.lastSeen!);
                            return Text('last seen $lastSeenStr', style: const TextStyle(color: Colors.grey, fontSize: 10));
                          }
                          
                          return const Text('Offline', style: TextStyle(color: Colors.grey, fontSize: 10));
                        },
                      );
                    },
                  )
                else
                  Text(widget.isWithAdmin ? 'Official Account' : 'Group Chat', style: const TextStyle(color: Colors.grey, fontSize: 10)),
              ],
            ),
          ),
          if (isPrivate && otherUserId.isNotEmpty && !widget.isWithAdmin)
            FutureBuilder<UserModel?>(
              future: _authService.getUserData(otherUserId),
              builder: (context, snapshot) {
                final otherUser = snapshot.data;
                return IconButton(
                  icon: Icon(Icons.phone_outlined, color: gold, size: 22),
                  onPressed: () {
                    if (otherUser != null) {
                      _callUser(otherUser);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('User information not available'))
                      );
                    }
                  },
                );
              },
            ),
          const SizedBox(width: 8),
          PremiumSOSButton(onTap: _sendSOS),
        ],
      ),
    );
  }

  String _formatLastSeen(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    return DateFormat('MMM d').format(time);
  }

  Widget _buildDateHeader(DateTime date, bool isDark, Color gold) {
    String text;
    final now = DateTime.now();
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      text = 'Today';
    } else if (date.day == now.day - 1 && date.month == now.month && date.year == now.year) {
      text = 'Yesterday';
    } else {
      text = DateFormat('MMMM d').format(date);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: gold.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: gold.withOpacity(0.2)),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: gold, letterSpacing: 0.5)),
    );
  }

  Widget _buildReplyPreview(bool isDark, Color gold) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GlassContainer(
        isDark: isDark,
        padding: const EdgeInsets.all(10),
        borderRadius: 15,
        containerOpacity: 0.1,
        child: Row(
          children: [
            Container(width: 4, height: 40, decoration: BoxDecoration(color: gold, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_replyingTo!.senderName, style: TextStyle(color: gold, fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(_replyingTo!.isImage ? '📷 Image' : (_replyingTo!.isVoice ? '🎤 Voice Message' : _replyingTo!.text), 
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 12)),
                ],
              ),
            ),
            IconButton(icon: const Icon(Icons.close, size: 18, color: Colors.grey), onPressed: () => setState(() => _replyingTo = null)),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message, bool isMe, bool isDark, Color gold, bool isPrivate) {
    final bubbleColor = isMe ? gold : (isDark ? Colors.white.withOpacity(0.08) : Colors.white);
    final textColor = isMe ? Colors.black : (isDark ? Colors.white : Colors.black87);
    final isFromAdmin = message.senderName == 'ZedPool';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            GestureDetector(
              onTap: () {
                if (!isFromAdmin) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfileViewScreen(userId: message.senderId)));
                }
              },
              child: Container(
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: gold.withOpacity(0.3), width: 1),
                ),
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: gold.withOpacity(0.1),
                  backgroundImage: isFromAdmin 
                      ? const AssetImage('assets/icon/app_icon.png') as ImageProvider
                      : (message.senderPhotoUrl != null ? NetworkImage(message.senderPhotoUrl!) : null),
                  child: (message.senderPhotoUrl == null && !isFromAdmin) ? Icon(Icons.person, size: 14, color: gold) : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showMessageOptions(message),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe && !isPrivate)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(
                        message.senderName,
                        style: TextStyle(fontSize: 10, color: gold, fontWeight: FontWeight.bold),
                      ),
                    ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: message.isImage ? const EdgeInsets.all(5) : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: isMe ? const Radius.circular(20) : Radius.zero,
                            bottomRight: isMe ? Radius.zero : const Radius.circular(20),
                          ),
                          border: isMe ? null : Border.all(color: gold.withOpacity(0.1)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (message.replyToText != null) 
                              Container(
                                padding: const EdgeInsets.all(8),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: (isMe ? Colors.black : gold).withOpacity(0.1), 
                                  borderRadius: BorderRadius.circular(12), 
                                  border: Border(left: BorderSide(color: isMe ? Colors.black45 : gold, width: 3))
                                ),
                                child: Text(
                                  message.replyToText!, 
                                  maxLines: 2, 
                                  style: TextStyle(fontSize: 11, color: isMe ? Colors.black54 : Colors.grey, fontStyle: FontStyle.italic)
                                ),
                              ),
                            if (message.isImage) 
                              GestureDetector(
                                onTap: () {
                                  if (message.imageUrl != null) _viewImage(message.imageUrl!);
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: Image.network(
                                    message.imageUrl!, 
                                    width: 250,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        width: 200, height: 200, 
                                        color: gold.withOpacity(0.05), 
                                        child: Center(child: CircularProgressIndicator(color: gold, value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null))
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) => Container(width: 200, height: 200, color: Colors.grey.withOpacity(0.1), child: Icon(Icons.broken_image, color: gold)),
                                  ),
                                ),
                              ),
                            if (message.isVoice && message.voiceUrl != null) 
                              VoiceMessageBubble(
                                url: message.voiceUrl!,
                                duration: message.voiceDuration,
                                isMe: isMe,
                                gold: gold,
                              ),
                            if (message.text.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2, left: 2, right: 2),
                                child: Text(
                                  message.text, 
                                  style: TextStyle(color: textColor, fontSize: 15, height: 1.4),
                                ),
                              ),
                            const SizedBox(height: 5),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  DateFormat('h:mm a').format(message.timestamp), 
                                  style: TextStyle(fontSize: 9, color: isMe ? Colors.black45 : Colors.grey, fontWeight: FontWeight.bold)
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 4),
                                  _buildStatusIcon(message.status, Colors.black45),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (message.reactions.isNotEmpty)
                        Positioned(
                          bottom: -10,
                          right: isMe ? null : -5,
                          left: isMe ? -5 : null,
                          child: GlassContainer(
                            isDark: isDark,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            borderRadius: 12,
                            containerOpacity: 0.1,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: message.reactions.values.toSet().take(2).map((e) => Text(e, style: const TextStyle(fontSize: 12))).toList(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfileViewScreen(userId: _currentUserId!)));
              },
              child: Container(
                padding: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: gold.withOpacity(0.3), width: 1),
                ),
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: gold.withOpacity(0.1),
                  backgroundImage: isFromAdmin 
                      ? const AssetImage('assets/icon/app_icon.png') as ImageProvider
                      : (message.senderPhotoUrl != null ? NetworkImage(message.senderPhotoUrl!) : null),
                  child: (message.senderPhotoUrl == null && !isFromAdmin) ? Icon(Icons.person, size: 10, color: gold) : null,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    int mins = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return "$mins:${remainingSeconds.toString().padLeft(2, '0')}";
  }

  Widget _buildStatusIcon(MessageStatus status, Color color) {
    switch (status) {
      case MessageStatus.sent: return Icon(Icons.done, size: 12, color: color);
      case MessageStatus.delivered: return Icon(Icons.done_all, size: 12, color: color);
      case MessageStatus.read: return const Icon(Icons.done_all, size: 12, color: Colors.blue);
    }
  }

  void _showMessageOptions(MessageModel message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassContainer(
        isDark: Theme.of(context).brightness == Brightness.dark,
        borderRadius: 25,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['❤️', '👍', '😂', '😮', '😢', '🙏'].map((emoji) => IconButton(
                onPressed: () { _addReaction(message, emoji); Navigator.pop(context); },
                icon: Text(emoji, style: const TextStyle(fontSize: 26)),
              )).toList(),
            ),
            const Divider(color: Colors.white10),
            ListTile(leading: const Icon(Icons.reply, color: Color(0xFFD4AF37)), title: const Text('Reply'), onTap: () { setState(() => _replyingTo = message); Navigator.pop(context); }),
            ListTile(leading: const Icon(Icons.copy, color: Color(0xFFD4AF37)), title: const Text('Copy Text'), onTap: () { Clipboard.setData(ClipboardData(text: message.text)); Navigator.pop(context); }),
            ListTile(leading: const Icon(Icons.delete_outline, color: Colors.red), title: const Text('Delete for me', style: TextStyle(color: Colors.red)), onTap: () { _deleteMessage(message); Navigator.pop(context); }),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _deleteMessage(MessageModel message) async {
    if (_currentUserId != null) {
      await _chatService.deleteMessageForMe(rideId: widget.privateChatId == null ? widget.rideId : null, privateChatId: widget.privateChatId, messageId: message.id, userId: _currentUserId!);
    }
  }

  void _viewImage(String url) {
    showDialog(context: context, builder: (context) => Dialog.fullscreen(child: Stack(children: [Image.network(url, fit: BoxFit.contain, width: double.infinity, height: double.infinity), Positioned(top: 40, left: 20, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context)))])));
  }

  Widget _buildMessageInput(bool isDark, Color gold) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: GlassContainer(
        isDark: isDark,
        borderRadius: 30,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        containerOpacity: 0.05,
        child: Row(
          children: [
            if (!_isRecording)
              IconButton(
                icon: Icon(Icons.add_circle_outline, color: gold, size: 24), 
                onPressed: _isUploading ? null : _showImageSourceAction
              ),
            Expanded(
              child: _isRecording 
                ? _buildRecordingStatus(gold)
                : TextField(
                    controller: _messageController,
                    onChanged: _onTextChanged,
                    enabled: !_isUploading,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: _isUploading ? 'Uploading...' : 'Type a message...', 
                      border: InputBorder.none, 
                      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey, fontSize: 14)
                    ),
                  ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onLongPressStart: _isUploading ? null : (_) => _startRecording(),
              onLongPressEnd: _isUploading ? null : (_) => _stopRecording(),
              onTap: () { if (_messageController.text.trim().isNotEmpty && !_isUploading) _sendMessage(); },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isUploading ? Colors.grey : gold, 
                  shape: BoxShape.circle,
                  boxShadow: _isUploading ? [] : [BoxShadow(color: gold.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Icon(
                  _messageController.text.trim().isEmpty ? (_isRecording ? Icons.mic : Icons.mic_none) : Icons.send, 
                  color: Colors.black, 
                  size: 20
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingStatus(Color gold) {
    return Row(
      children: [
        const Icon(Icons.fiber_manual_record, color: Colors.red, size: 16),
        const SizedBox(width: 8),
        Text(
          _formatDuration(_currentRecordDuration), 
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Recording...', 
            style: TextStyle(color: Colors.grey.withOpacity(0.7), fontSize: 13, fontStyle: FontStyle.italic)
          )
        ),
      ],
    );
  }

  Widget _buildEmptyState(Color gold) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.chat_bubble_outline, size: 60, color: gold.withOpacity(0.2)), const SizedBox(height: 16), const Text('No messages yet. Start a conversation!', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500))]));
  }

  Widget _buildQuickReplies(bool isDark, Color gold) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        itemCount: _quickReplies.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(right: 10),
          child: ActionChip(
            label: Text(_quickReplies[index], style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)), 
            backgroundColor: gold.withOpacity(0.1), 
            side: BorderSide(color: gold.withOpacity(0.3)),
            onPressed: _isUploading ? null : () => _sendMessage(text: _quickReplies[index]),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          )
        ),
      ),
    );
  }

  void _sendSOS() async {
    if (_currentUserId == null) return;
    bool confirm = await showDialog(context: context, builder: (context) => AlertDialog(backgroundColor: Colors.transparent, contentPadding: EdgeInsets.zero, content: GlassContainer(isDark: Theme.of(context).brightness == Brightness.dark, borderRadius: 20, child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('EMERGENCY SOS', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18)), const SizedBox(height: 15), const Text('Alert Admin and dial emergency?', textAlign: TextAlign.center), const SizedBox(height: 20), Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('YES', style: TextStyle(color: Colors.white)))])]))));
    if (confirm == true) {
      await _safetyService.reportIssue(widget.rideId, _currentUserId!, 'SOS SIGNAL', isSOS: true);
      launchUrl(Uri(scheme: 'tel', path: emergencyPhoneNumber));
    }
  }
}

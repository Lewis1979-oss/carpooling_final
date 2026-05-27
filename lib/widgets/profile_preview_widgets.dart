import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/theme_service.dart';
import '../services/chat_service.dart';
import '../services/voice_call_service.dart';
import '../screens/chat_screen.dart';
import '../screens/user_profile_view_screen.dart';
import '../screens/voice_call_screen.dart';
import 'call_choice_dialog.dart';

class FullImageScreen extends StatelessWidget {
  final String? imageUrl;
  final File? imageFile;
  final String? assetPath;
  final String heroTag;

  const FullImageScreen({
    super.key,
    this.imageUrl,
    this.imageFile,
    this.assetPath,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: imageFile != null
                ? Image.file(imageFile!, fit: BoxFit.contain, width: double.infinity)
                : (assetPath != null
                    ? Image.asset(assetPath!, fit: BoxFit.contain, width: double.infinity)
                    : (imageUrl != null
                        ? Image.network(imageUrl!, fit: BoxFit.contain, width: double.infinity)
                        : const Icon(Icons.person, size: 200, color: Colors.white))),
          ),
        ),
      ),
    );
  }
}

void showProfilePreview(
  BuildContext context, {
  required UserModel user,
  required String currentUserId,
  required String heroTag,
}) {
  final themeService = Provider.of<ThemeService>(context, listen: false);
  final gold = themeService.goldAccent;
  final isDark = themeService.isDarkMode;
  final imageUrl = user.profilePic;

  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 50),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                PageRouteBuilder(
                  opaque: false,
                  barrierColor: Colors.black,
                  pageBuilder: (_, __, ___) => FullImageScreen(
                    imageUrl: imageUrl,
                    heroTag: heroTag,
                  ),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                ),
              );
            },
            child: Hero(
              tag: heroTag,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  image: imageUrl != null
                      ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
                      : null,
                ),
                child: (imageUrl == null)
                    ? Icon(Icons.person, size: 140, color: gold.withOpacity(0.5))
                    : null,
              ),
            ),
          ),
          Container(
            width: 280,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(0),
                bottomRight: Radius.circular(0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Message Action
                IconButton(
                  icon: Icon(Icons.message, color: gold, size: 22),
                  onPressed: () {
                    Navigator.pop(context);
                    final chatService = ChatService();
                    final chatId = chatService.getPrivateChatId(currentUserId, user.id);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          rideId: '',
                          destinationName: '',
                          privateChatId: chatId,
                          otherUserName: user.name,
                          otherUserPhotoUrl: user.profilePic,
                        ),
                      ),
                    );
                  },
                ),
                // Call Action (Respecting Privacy)
                if (user.phone != null && !user.hidePhoneNumber)
                  IconButton(
                    icon: Icon(Icons.call, color: gold, size: 22),
                    onPressed: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (context) => CallChoiceDialog(
                          otherUser: user,
                          gold: gold,
                          isDark: isDark,
                          onZedPoolCall: () {
                            final callService = Provider.of<VoiceCallService>(context, listen: false);
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
                            final Uri tel = Uri(scheme: 'tel', path: user.phone);
                            if (await canLaunchUrl(tel)) await launchUrl(tel);
                          },
                        ),
                      );
                    },
                  ),
                // Info Action
                IconButton(
                  icon: Icon(Icons.info_outline, color: gold, size: 22),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserProfileViewScreen(userId: user.id),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../models/chat_model.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../services/chat_service.dart';
import '../services/ride_service.dart';
import '../services/voice_call_service.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/profile_preview_widgets.dart';
import 'chat_screen.dart';
import 'package:intl/intl.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _activeFilter = 'All'; 

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterMenu(BuildContext context, bool isDark, Color gold) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassContainer(
        isDark: isDark,
        borderRadius: 30,
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('FILTER MESSAGES', style: TextStyle(color: gold, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 20),
            _buildFilterOption('All', Icons.all_inclusive, isDark, gold),
            _buildFilterOption('Unread', Icons.mark_email_unread_outlined, isDark, gold),
            _buildFilterOption('Groups', Icons.group_outlined, isDark, gold),
            _buildFilterOption('Private', Icons.person_outline, isDark, gold),
            _buildFilterOption('Calls', Icons.phone_outlined, isDark, gold),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String label, IconData icon, bool isDark, Color gold) {
    bool isSelected = _activeFilter == label;
    return ListTile(
      leading: Icon(icon, color: isSelected ? gold : Colors.grey),
      title: Text(label, style: TextStyle(color: isSelected ? gold : (isDark ? Colors.white : Colors.black87), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      trailing: isSelected ? Icon(Icons.check_circle, color: gold, size: 18) : null,
      onTap: () {
        setState(() => _activeFilter = label);
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;
    final activeGold = themeService.goldAccent;

    return GlassScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                physics: const BouncingScrollPhysics(),
                children: [
                  const SizedBox(height: 10),
                  Text(
                    'Messages',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your premium conversations',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 25),
                  _buildSearchBar(isDark, activeGold),
                  const SizedBox(height: 30),
                  if (_activeFilter == 'Calls')
                    _buildCallHistoryList(user?.uid ?? '', activeGold, isDark)
                  else
                    _buildUnifiedChatList(user?.uid ?? '', activeGold, isDark),
                  const SizedBox(height: 40),
                  Center(
                    child: Text(
                      'No more messages',
                      style: TextStyle(color: activeGold.withOpacity(0.3), fontSize: 13, letterSpacing: 1),
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark, Color gold) {
    return Row(
      children: [
        Expanded(
          child: GlassContainer(
            isDark: isDark,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            borderRadius: 15,
            containerOpacity: 0.1, 
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search messages...',
                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.withOpacity(0.6), fontSize: 14),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, color: isDark ? Colors.white30 : Colors.grey, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => _showFilterMenu(context, isDark, gold),
          child: GlassContainer(
            isDark: isDark,
            padding: const EdgeInsets.all(10),
            borderRadius: 12,
            containerOpacity: 0.1,
            child: Icon(Icons.tune, color: gold, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildUnifiedChatList(String userId, Color gold, bool isDark) {
    return StreamBuilder<List<ChatListItem>>(
      stream: _getUnifiedChatsStream(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()));
        }
        
        var chats = snapshot.data ?? [];

        if (_activeFilter == 'Groups') chats = chats.where((c) => c.isGroup).toList();
        if (_activeFilter == 'Private') chats = chats.where((c) => !c.isGroup).toList();

        return Column(
          children: chats.map((chat) {
            // Logic to filter by contact name will happen inside _buildChatTile
            // but for immediate UI feedback we check group titles and snippets here
            if (_searchQuery.isNotEmpty) {
               bool matchesTitle = chat.title.toLowerCase().contains(_searchQuery);
               bool matchesMsg = chat.lastMessage.toLowerCase().contains(_searchQuery);
               // We will use a unique key for the tile so it knows to filter properly
               return _buildChatTile(context, chat, userId, gold, isDark, matchesInitialSearch: matchesTitle || matchesMsg);
            }
            return _buildChatTile(context, chat, userId, gold, isDark);
          }).whereType<Widget>().toList(),
        );
      },
    );
  }

  Widget _buildCallHistoryList(String userId, Color gold, bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('call_history')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()));
        }

        final docs = snapshot.data?.docs ?? [];
        var filteredDocs = docs;

        if (_searchQuery.isNotEmpty) {
          filteredDocs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['otherName'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery);
          }).toList();
        }

        if (filteredDocs.isEmpty) return _buildEmptyState('No records found.', gold);

        return Column(
          children: filteredDocs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
            final type = data['type'] ?? 'incoming'; 
            final otherName = data['otherName'] ?? 'Unknown';
            final otherPic = data['otherPic'];
            final otherId = data['otherId'];
            final bool isRead = data['isRead'] ?? true;
            final bool isMissed = type == 'missed';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: GlassContainer(
                isDark: isDark,
                padding: const EdgeInsets.all(4),
                borderRadius: 20,
                containerOpacity: (isMissed && !isRead) ? 0.2 : 0.05,
                color: (isMissed && !isRead) ? Colors.redAccent : null,
                child: ListTile(
                  onTap: () async {
                    final callService = Provider.of<VoiceCallService>(context, listen: false);
                    if (!isRead) {
                      await callService.markCallAsRead(doc.id);
                    }
                    if (otherId != null) {
                      final otherUser = await AuthService().getUserData(otherId);
                      if (otherUser != null) {
                        callService.makeCall(receiver: otherUser);
                      }
                    }
                  },
                  onLongPress: () => _confirmDeleteCall(doc.id),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    radius: 28,
                    backgroundColor: gold.withOpacity(0.1),
                    backgroundImage: otherPic != null ? NetworkImage(otherPic) : null,
                    child: otherPic == null ? Icon(Icons.person, color: gold) : null,
                  ),
                  title: Text(
                    otherName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      Icon(
                        type == 'outgoing' ? Icons.call_made : (isMissed ? Icons.call_missed : Icons.call_received),
                        size: 14,
                        color: isMissed ? Colors.red : Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        type.toUpperCase(),
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatTime(timestamp),
                        style: TextStyle(color: gold, fontSize: 11),
                      ),
                    ],
                  ),
                  trailing: Icon(Icons.phone, color: gold, size: 20),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _confirmDeleteCall(String logId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: GlassContainer(
          isDark: Theme.of(context).brightness == Brightness.dark,
          borderRadius: 20,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Delete History?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 15),
              const Text('Are you sure you want to delete this call record?', textAlign: TextAlign.center),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  ElevatedButton(
                    onPressed: () {
                      Provider.of<VoiceCallService>(context, listen: false).deleteCallLog(logId);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Delete', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Stream<List<ChatListItem>> _getUnifiedChatsStream(String userId) {
    final controller = StreamController<List<ChatListItem>>();
    List<ChatListItem> groups = [];
    List<ChatListItem> privates = [];

    void emit() {
      final combined = [...groups, ...privates];
      combined.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (!controller.isClosed) controller.add(combined);
    }

    final s1 = FirebaseFirestore.instance.collection('rides').snapshots().listen((snap) {
      groups = snap.docs.where((doc) {
        final data = doc.data();
        final passengers = List<String>.from(data['passengers'] ?? []);
        final driverId = data['driverId'] ?? '';
        final deletedBy = List<String>.from(data['deletedBy'] ?? []);
        return (passengers.contains(userId) || driverId == userId) && !deletedBy.contains(userId);
      }).map((doc) {
        final data = doc.data();
        return ChatListItem(
          id: doc.id,
          title: 'Ride to ${data['destination']}',
          lastMessage: data['lastMessage'] ?? 'No messages yet',
          timestamp: (data['lastTimestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          isGroup: true,
          otherUserId: null,
          rideId: doc.id,
        );
      }).toList();
      emit();
    });

    final s2 = FirebaseFirestore.instance.collection('private_chats').where('participants', arrayContains: userId).snapshots().listen((snap) {
      privates = snap.docs.where((doc) {
        final data = doc.data();
        final hiddenBy = data['hiddenBy'] ?? [];
        return !(hiddenBy as List).contains(userId);
      }).map((doc) {
        final data = doc.data();
        final List participants = data['participants'] ?? [];
        final otherId = participants.firstWhere((id) => id != userId, orElse: () => '');
        return ChatListItem(
          id: doc.id,
          title: '', 
          lastMessage: data['lastMessage'] ?? 'No messages yet',
          timestamp: (data['lastTimestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          isGroup: false,
          otherUserId: otherId,
          rideId: data['rideId'],
        );
      }).toList();
      emit();
    });

    controller.onCancel = () { s1.cancel(); s2.cancel(); };
    return controller.stream;
  }

  Widget? _buildChatTile(BuildContext context, ChatListItem chat, String currentUserId, Color gold, bool isDark, {bool matchesInitialSearch = false}) {
    if (chat.isGroup) {
      if (_searchQuery.isNotEmpty && !matchesInitialSearch) return null;
      
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('rides').doc(chat.id).collection('messages')
            .where('senderId', isNotEqualTo: currentUserId)
            .where('status', isNotEqualTo: 'read')
            .snapshots(),
        builder: (context, unreadSnap) {
          final unreadCount = unreadSnap.data?.docs.length ?? 0;
          if (_activeFilter == 'Unread' && unreadCount == 0) return const SizedBox.shrink();

          return _buildChatTileUI(
            context,
            title: chat.title,
            subtitle: chat.lastMessage,
            time: _formatTime(chat.timestamp),
            imageUrl: null,
            unreadCount: unreadCount,
            isOnline: false,
            isGroup: true,
            isDark: isDark,
            gold: gold,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(rideId: chat.id, destinationName: chat.title.replaceFirst('Ride to ', '')))),
          );
        },
      );
    } else {
      return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(chat.otherUserId).snapshots(),
        builder: (context, userSnap) {
          if (!userSnap.hasData || !userSnap.data!.exists) return const SizedBox.shrink();
          final user = UserModel.fromMap(userSnap.data!.data() as Map<String, dynamic>, userSnap.data!.id);
          final isAdmin = user.role == 'admin';
          
          // Perform advanced contact name search here
          if (_searchQuery.isNotEmpty && !matchesInitialSearch) {
             if (!user.name.toLowerCase().contains(_searchQuery)) {
               return const SizedBox.shrink();
             }
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('private_chats').doc(chat.id).collection('messages')
                .where('senderId', isNotEqualTo: currentUserId)
                .where('status', isNotEqualTo: 'read')
                .snapshots(),
            builder: (context, unreadSnap) {
              final unreadCount = unreadSnap.data?.docs.length ?? 0;
              if (_activeFilter == 'Unread' && unreadCount == 0) return const SizedBox.shrink();

              return _buildChatTileUI(
                context,
                title: isAdmin ? 'ZedPool' : user.name,
                subtitle: chat.lastMessage,
                time: _formatTime(chat.timestamp),
                imageUrl: isAdmin ? null : user.profilePic,
                unreadCount: unreadCount,
                isOnline: user.isOnline,
                isGroup: false,
                isDark: isDark,
                gold: gold,
                isAdmin: isAdmin,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(
                  rideId: chat.rideId ?? '',
                  destinationName: isAdmin ? 'Support' : '',
                  privateChatId: chat.id,
                  otherUserName: isAdmin ? 'ZedPool' : user.name,
                  otherUserPhotoUrl: isAdmin ? null : user.profilePic,
                  isWithAdmin: isAdmin,
                ))),
                onAvatarTap: !isAdmin ? () {
                  showProfilePreview(context, user: user, currentUserId: currentUserId, heroTag: 'inbox_${user.id}');
                } : null,
                heroTag: 'inbox_${user.id}',
              );
            },
          );
        },
      );
    }
  }

  Widget _buildChatTileUI(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String time,
    required String? imageUrl,
    required int unreadCount,
    required bool isOnline,
    required bool isGroup,
    required bool isDark,
    required Color gold,
    required VoidCallback onTap,
    VoidCallback? onAvatarTap,
    String? heroTag,
    bool isAdmin = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        isDark: isDark,
        padding: const EdgeInsets.all(4),
        borderRadius: 20,
        containerOpacity: 0.05,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: GestureDetector(
            onTap: onAvatarTap,
            child: Hero(
              tag: heroTag ?? title,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: gold.withOpacity(0.3), width: 1.5),
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: gold.withOpacity(0.1),
                      backgroundImage: isAdmin 
                          ? const AssetImage('assets/icon/app_icon.png') as ImageProvider
                          : (imageUrl != null ? NetworkImage(imageUrl) : null),
                      child: (imageUrl == null && !isAdmin) ? Icon(isGroup ? Icons.group : Icons.person, color: gold) : null,
                    ),
                  ),
                  if (isOnline && !isAdmin)
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: isDark ? const Color(0xFF0D3B3B) : Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.blue.withOpacity(0.5), width: 0.5),
                        ),
                        child: const Text(
                          'OFFICIAL',
                          style: TextStyle(color: Colors.blue, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                time,
                style: TextStyle(color: gold, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: const Color(0xFF4DB6AC), shape: BoxShape.circle),
                    child: Text(
                      unreadCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    if (now.day == timestamp.day && now.month == timestamp.month && now.year == timestamp.year) {
      return DateFormat('h:mm a').format(timestamp);
    }
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    if (yesterday.day == timestamp.day && yesterday.month == timestamp.month && yesterday.year == timestamp.year) {
      return 'Yesterday';
    }
    return DateFormat('EEE').format(timestamp);
  }

  Widget _buildEmptyState(String message, Color gold) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 50),
          Icon(Icons.chat_bubble_outline, size: 60, color: gold.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class ChatListItem {
  final String id;
  final String title;
  final String lastMessage;
  final DateTime timestamp;
  final bool isGroup;
  final String? otherUserId;
  final String? rideId;

  ChatListItem({
    required this.id,
    required this.title,
    required this.lastMessage,
    required this.timestamp,
    required this.isGroup,
    this.otherUserId,
    this.rideId,
  });
}

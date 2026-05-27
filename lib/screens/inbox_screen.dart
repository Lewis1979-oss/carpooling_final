import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:rxdart/rxdart.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../services/chat_service.dart';
import '../models/user_model.dart';
import '../widgets/glass_widgets.dart';
import 'chat_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final TextEditingController _searchController = TextEditingController();
  
  String _searchQuery = "";
  String _filterType = "All"; // "All", "Unread Only", "Groups", "Individual"

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<List<ChatEntry>> _getCombinedChatsStream() {
    if (_currentUserId == null) return Stream.value([]);

    // Stream 1: Private Chats
    final privateChatsStream = _db.collection('private_chats')
        .where('participants', arrayContains: _currentUserId)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => ChatEntry.fromPrivateChat(doc, _currentUserId!)).toList());

    // Stream 2: Group Chats (Where I am Driver)
    final driverRidesStream = _db.collection('rides')
        .where('driverId', isEqualTo: _currentUserId)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => ChatEntry.fromRide(doc)).toList());

    // Stream 3: Group Chats (Where I am Passenger)
    final passengerRidesStream = _db.collection('rides')
        .where('passengers', arrayContains: _currentUserId)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => ChatEntry.fromRide(doc)).toList());

    return CombineLatestStream.combine3(
      privateChatsStream,
      driverRidesStream,
      passengerRidesStream,
      (List<ChatEntry> private, List<ChatEntry> driver, List<ChatEntry> passenger) {
        final all = [...private, ...driver, ...passenger];
        
        // Remove duplicates by ID (in case someone is both driver and passenger, though unlikely)
        final Map<String, ChatEntry> uniqueChats = {};
        for (var chat in all) {
          uniqueChats[chat.id] = chat;
        }

        List<ChatEntry> list = uniqueChats.values.toList();
        list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return list;
      },
    );
  }

  void _showFilterSheet(BuildContext context, Color gold, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassContainer(
        isDark: isDark,
        borderRadius: 25,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4, 
              decoration: BoxDecoration(color: gold.withOpacity(0.3), borderRadius: BorderRadius.circular(2))
            ),
            const SizedBox(height: 20),
            _buildFilterOption("All", Icons.all_inclusive, gold, isDark),
            _buildFilterOption("Unread Only", Icons.mark_chat_unread_outlined, gold, isDark),
            _buildFilterOption("Individual", Icons.person_outline, gold, isDark),
            _buildFilterOption("Groups", Icons.group_outlined, gold, isDark),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String type, IconData icon, Color gold, bool isDark) {
    bool isSelected = _filterType == type;
    return ListTile(
      leading: Icon(icon, color: isSelected ? gold : Colors.grey),
      title: Text(
        type, 
        style: TextStyle(
          color: isSelected ? gold : (isDark ? Colors.white : Colors.black87), 
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
        )
      ),
      trailing: isSelected ? Icon(Icons.check_circle, color: gold, size: 20) : null,
      onTap: () {
        setState(() => _filterType = type);
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;
    final goldColor = themeService.goldAccent;
    final bodyColor = Theme.of(context).textTheme.bodyLarge?.color ?? (isDark ? Colors.white : Colors.black87);

    if (_currentUserId == null) {
      return const Center(child: Text("Please log in to see your messages."));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          _buildHeader(isDark, goldColor, bodyColor),
          Expanded(
            child: StreamBuilder<List<ChatEntry>>(
              stream: _getCombinedChatsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var chats = snapshot.data ?? [];

                // Filter by type first
                if (_filterType == "Unread Only") {
                  chats = chats.where((c) => c.unreadCount > 0).toList();
                } else if (_filterType == "Groups") {
                  chats = chats.where((c) => c.isGroup).toList();
                } else if (_filterType == "Individual") {
                  chats = chats.where((c) => !c.isGroup).toList();
                }

                // Search filtering logic with FutureBuilder for usernames
                return _buildFilteredListView(chats, isDark, goldColor);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredListView(List<ChatEntry> allChats, bool isDark, Color gold) {
    // If no search query, render normally
    if (_searchQuery.isEmpty) {
      if (allChats.isEmpty) return _buildEmptyState("No messages yet", Icons.message_outlined, gold);
      return _renderList(allChats, isDark, gold);
    }

    // With search query, we need to filter. 
    final filtered = allChats.where((chat) {
      final query = _searchQuery.toLowerCase();
      final lastMsg = chat.lastMessage.toLowerCase();
      final name = chat.displayName.toLowerCase();
      return lastMsg.contains(query) || name.contains(query);
    }).toList();

    if (filtered.isEmpty) return _buildEmptyState("No results found", Icons.search_off_rounded, gold);

    return _renderList(filtered, isDark, gold);
  }

  Widget _renderList(List<ChatEntry> chats, bool isDark, Color gold) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: chats.length + 1,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        if (index == chats.length) return _buildFooter(gold);
        return _buildChatTile(chats[index], isDark, gold);
      },
    );
  }

  Widget _buildHeader(bool isDark, Color gold, Color bodyColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 5, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Messages",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: bodyColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Your conversations",
            style: TextStyle(
              fontSize: 15,
              color: bodyColor.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20), // Increased spacing
          Row(
            children: [
              Expanded(
                child: GlassContainer(
                  isDark: isDark,
                  height: 50, // Fixed height to prevent collapse
                  borderRadius: 15,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  containerOpacity: 0.1,
                  child: Center(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(fontSize: 14),
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: "Search messages...",
                        hintStyle: TextStyle(color: Colors.grey.withOpacity(0.7), fontSize: 14),
                        border: InputBorder.none,
                        icon: Icon(Icons.search, color: Colors.grey.withOpacity(0.7), size: 20),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _showFilterSheet(context, gold, isDark),
                child: GlassContainer(
                  isDark: isDark,
                  width: 50, // Fixed width
                  height: 50, // Fixed height
                  borderRadius: 15,
                  padding: EdgeInsets.zero,
                  containerOpacity: 0.1,
                  child: Center(
                    child: Icon(Icons.tune, color: gold, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChatTile(ChatEntry chat, bool isDark, Color gold) {
    return FutureBuilder<UserModel?>(
      future: chat.isGroup ? Future.value(null) : AuthService().getUserData(chat.otherUserId!),
      builder: (context, userSnap) {
        final otherUser = userSnap.data;
        final String name = chat.isGroup ? chat.displayName : (otherUser?.name ?? 'Loading...');
        final String? pic = chat.isGroup ? chat.displayPic : otherUser?.profilePic;
        final bool isOnline = !chat.isGroup && (otherUser?.isOnline ?? false);

        // If searching, check if name matches if the message didn't
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          if (!name.toLowerCase().contains(query) && !chat.lastMessage.toLowerCase().contains(query)) {
            return const SizedBox.shrink();
          }
        }

        final bool isEmpty = chat.lastMessage == 'No messages yet';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: GlassContainer(
            isDark: isDark,
            padding: const EdgeInsets.all(4),
            borderRadius: 20,
            containerOpacity: chat.unreadCount > 0 ? 0.15 : 0.05,
            child: ListTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      rideId: chat.isGroup ? chat.id : (chat.rideId ?? ""),
                      destinationName: chat.isGroup ? name : "Private Chat",
                      privateChatId: chat.isGroup ? null : chat.id,
                      otherUserName: chat.isGroup ? null : name,
                      otherUserPhotoUrl: chat.isGroup ? null : pic,
                    ),
                  ),
                );
              },
              leading: Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: gold.withOpacity(0.1),
                    backgroundImage: pic != null ? NetworkImage(pic) : null,
                    child: pic == null ? Icon(chat.isGroup ? Icons.group : Icons.person, color: gold, size: 28) : null,
                  ),
                  if (isOnline)
                    Positioned(
                      right: 2, bottom: 2,
                      child: Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: isDark ? Colors.black : Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              title: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: isEmpty 
                  ? Center(
                      child: Text(
                        chat.lastMessage,
                        style: const TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic),
                      ),
                    )
                  : RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: TextStyle(
                          color: chat.unreadCount > 0 ? (isDark ? Colors.white : Colors.black87) : Colors.grey,
                          fontSize: 13,
                        ),
                        children: _buildSubtitleSpans(chat, isDark),
                      ),
                    ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTime(chat.timestamp),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  if (chat.unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Color(0xFF64D2D2), shape: BoxShape.circle),
                      child: Text(
                        chat.unreadCount.toString(),
                        style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<TextSpan> _buildSubtitleSpans(ChatEntry chat, bool isDark) {
    final String lastMsg = chat.lastMessage;
    final bool isUnread = chat.unreadCount > 0;
    final fontWeight = isUnread ? FontWeight.w600 : FontWeight.normal;

    if (chat.isGroup) {
      if (lastMsg.contains(': ')) {
        final parts = lastMsg.split(': ');
        return [
          TextSpan(text: '${parts[0]}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: parts.sublist(1).join(': '), style: TextStyle(fontWeight: fontWeight)),
        ];
      }
      return [TextSpan(text: lastMsg, style: TextStyle(fontWeight: fontWeight))];
    } else {
      // Private Chat
      if (chat.lastSenderId == _currentUserId) {
        return [
          const TextSpan(text: 'You: ', style: TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: lastMsg, style: TextStyle(fontWeight: fontWeight)),
        ];
      }
      return [TextSpan(text: lastMsg, style: TextStyle(fontWeight: fontWeight))];
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time).inDays;

    if (time.day == now.day && time.month == now.month && time.year == now.year) {
      return DateFormat('hh:mm a').format(time);
    } else if (difference == 0 && time.day != now.day) {
      // Handle edge case for late night yesterday vs early morning today
      return "Yesterday";
    } else if (time.day == now.day - 1 && time.month == now.month && time.year == now.year) {
      return "Yesterday";
    } else if (difference < 7) {
      return DateFormat('EEE').format(time); // Mon, Tue, etc.
    } else {
      return DateFormat('MMM d').format(time);
    }
  }

  Widget _buildEmptyState(String title, IconData icon, Color gold) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: gold.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildFooter(Color gold) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          "No more messages",
          style: TextStyle(color: Colors.grey.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
    );
  }
}

class ChatEntry {
  final String id;
  final String lastMessage;
  final DateTime timestamp;
  final bool isGroup;
  final String displayName;
  final String? displayPic;
  final int unreadCount;
  final String? otherUserId;
  final String? rideId;
  final String? lastSenderId;

  ChatEntry({
    required this.id,
    required this.lastMessage,
    required this.timestamp,
    required this.isGroup,
    required this.displayName,
    this.displayPic,
    required this.unreadCount,
    this.otherUserId,
    this.rideId,
    this.lastSenderId,
  });

  factory ChatEntry.fromPrivateChat(DocumentSnapshot doc, String currentUserId) {
    final data = doc.data() as Map<String, dynamic>;
    final participants = List<String>.from(data['participants'] ?? []);
    final otherId = participants.firstWhere((id) => id != currentUserId, orElse: () => '');
    
    return ChatEntry(
      id: doc.id,
      lastMessage: data['lastMessage'] ?? '',
      timestamp: (data['lastTimestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isGroup: false,
      displayName: "", 
      unreadCount: data['unreadCount_$currentUserId'] ?? 0,
      otherUserId: otherId,
      rideId: data['rideId'],
      lastSenderId: data['lastSenderId'],
    );
  }

  factory ChatEntry.fromRide(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatEntry(
      id: doc.id,
      lastMessage: data['lastMessage'] ?? 'No messages yet',
      timestamp: (data['lastTimestamp'] as Timestamp?)?.toDate() ?? (data['dateTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isGroup: true,
      displayName: data['destination'] ?? 'Group Ride',
      displayPic: null,
      unreadCount: 0,
      lastSenderId: data['lastSenderId'],
    );
  }
}

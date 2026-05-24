import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../services/voice_call_service.dart';
import '../widgets/glass_widgets.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;
    final goldColor = themeService.goldAccent;

    if (_currentUserId == null) {
      return const Center(child: Text("Please log in to see your messages."));
    }

    return DefaultTabController(
      length: 2,
      child: GlassScaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text("Inbox", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
          bottom: TabBar(
            indicatorColor: goldColor,
            labelColor: goldColor,
            unselectedLabelColor: isDark ? Colors.white70 : Colors.grey,
            tabs: const [
              Tab(text: "Messages"),
              Tab(text: "Calls"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMessageList(isDark, goldColor),
            _buildCallList(isDark, goldColor),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(bool isDark, Color goldColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('chats')
          .where('participants', arrayContains: _currentUserId)
          .orderBy('lastMessageTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState("No messages yet", Icons.message_outlined, goldColor);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final participants = List<String>.from(data['participants'] ?? []);
            final otherUserId = participants.firstWhere((id) => id != _currentUserId, orElse: () => '');
            
            return FutureBuilder<DocumentSnapshot>(
              future: _db.collection('users').doc(otherUserId).get(),
              builder: (context, userSnap) {
                final otherUser = userSnap.data?.data() as Map<String, dynamic>?;
                final name = otherUser?['name'] ?? 'Loading...';
                final profilePic = otherUser?['profilePic'];
                final lastMsg = data['lastMessage'] ?? '';
                final time = data['lastMessageTime'] as Timestamp?;
                final bool unread = data['unreadCount_$_currentUserId'] != null && data['unreadCount_$_currentUserId'] > 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: GlassContainer(
                    isDark: isDark,
                    padding: const EdgeInsets.all(4),
                    borderRadius: 20,
                    containerOpacity: unread ? 0.15 : 0.05,
                    child: ListTile(
                      onTap: () {
                        // Navigate to Chat
                      },
                      leading: CircleAvatar(
                        radius: 25,
                        backgroundColor: goldColor.withOpacity(0.1),
                        backgroundImage: profilePic != null ? NetworkImage(profilePic) : null,
                        child: profilePic == null ? Icon(Icons.person, color: goldColor) : null,
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: unread ? goldColor : Colors.grey)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (time != null)
                            Text(
                              DateFormat('hh:mm a').format(time.toDate()),
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          if (unread)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: goldColor, shape: BoxShape.circle),
                              child: Text(
                                data['unreadCount_$_currentUserId'].toString(),
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
          },
        );
      },
    );
  }

  Widget _buildCallList(bool isDark, Color goldColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('calls')
          .where('participants', arrayContains: _currentUserId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState("No recent calls", Icons.call_outlined, goldColor);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
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
                accentColor: (isMissed && !isRead) ? Colors.redAccent : null,
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
                    radius: 25,
                    backgroundColor: goldColor.withOpacity(0.1),
                    backgroundImage: otherPic != null ? NetworkImage(otherPic) : null,
                    child: otherPic == null ? Icon(Icons.person, color: goldColor) : null,
                  ),
                  title: Text(otherName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Row(
                    children: [
                      Icon(
                        isMissed ? Icons.call_missed : (type == 'outgoing' ? Icons.call_made : Icons.call_received),
                        size: 14,
                        color: isMissed ? Colors.redAccent : Colors.green,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('MMM d, hh:mm a').format((data['timestamp'] as Timestamp).toDate()),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  trailing: Icon(Icons.call, color: goldColor, size: 20),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteCall(String callId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Call Log?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await _db.collection('calls').doc(callId).delete();
              Navigator.pop(context);
            }, 
            child: const Text("Delete", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, IconData icon, Color gold) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: gold.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }
}

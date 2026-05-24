import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/admin_service.dart';
import '../services/chat_service.dart';
import '../services/theme_service.dart';
import '../widgets/glass_widgets.dart';
import 'chat_screen.dart';
import 'user_profile_view_screen.dart';
import '../models/chat_model.dart';

class AdminChatListScreen extends StatefulWidget {
  const AdminChatListScreen({super.key});

  @override
  State<AdminChatListScreen> createState() => _AdminChatListScreenState();
}

class _AdminChatListScreenState extends State<AdminChatListScreen> {
  final AdminService _adminService = AdminService();
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  bool _isSelectAllMode = false;
  final Set<String> _selectedUserIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleUserSelection(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
        if (_selectedUserIds.isEmpty) _isSelectAllMode = false;
      } else {
        _selectedUserIds.add(userId);
        _isSelectAllMode = true;
      }
    });
  }

  void _selectAllUsers(List<UserModel> users) {
    setState(() {
      if (_selectedUserIds.length == users.length) {
        _selectedUserIds.clear();
        _isSelectAllMode = false;
      } else {
        _selectedUserIds.addAll(users.map((u) => u.id));
        _isSelectAllMode = true;
      }
    });
  }

  void _showBroadcastDialog(List<UserModel> allUsers) {
    final TextEditingController broadcastController = TextEditingController();
    final themeService = Provider.of<ThemeService>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeService.isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Broadcast Message',
          style: TextStyle(color: themeService.goldAccent, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sending to ${_selectedUserIds.length} users',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: broadcastController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Type your message here...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              final messageText = broadcastController.text.trim();
              if (messageText.isNotEmpty) {
                final adminUid = FirebaseAuth.instance.currentUser?.uid;
                if (adminUid == null) return;

                Navigator.pop(context);
                _sendBroadcast(messageText, adminUid);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: themeService.goldAccent),
            child: const Text('SEND', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendBroadcast(String text, String adminUid) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sending broadcast messages...')),
    );

    int count = 0;
    for (String userId in _selectedUserIds) {
      final chatId = _chatService.getPrivateChatId(adminUid, userId);
      final message = MessageModel(
        id: '',
        senderId: adminUid,
        senderName: 'ZedPool', // Admin messages use 'ZedPool'
        text: text,
        timestamp: DateTime.now(),
        deletedBy: [],
      );
      await _chatService.sendPrivateMessage(chatId, message, userId);
      count++;
    }

    if (mounted) {
      setState(() {
        _selectedUserIds.clear();
        _isSelectAllMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Broadcast sent to $count users.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;
    final goldColor = themeService.goldAccent;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: goldColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isSelectAllMode ? '${_selectedUserIds.length} Selected' : 'User Support Chat',
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isSelectAllMode)
            IconButton(
              icon: const Icon(Icons.send, color: Colors.blue),
              onPressed: () {
                // We'll need the list of users to potentially select all if needed, 
                // but the dialog just needs the selection.
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              borderRadius: 15,
              isDark: isDark,
              accentColor: goldColor,
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search users...',
                  prefixIcon: Icon(Icons.search, color: goldColor),
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.4)),
                ),
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: _adminService.getAllUsers(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final allUsers = snapshot.data!;
                final filteredUsers = allUsers.where((u) => 
                  u.name.toLowerCase().contains(_searchQuery) || 
                  (u.phone?.contains(_searchQuery) ?? false)
                ).toList();

                if (filteredUsers.isEmpty) return const Center(child: Text('No users found.'));

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    final isSelected = _selectedUserIds.contains(user.id);

                    return GestureDetector(
                      onLongPress: () {
                        _showLongPressMenu(allUsers);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? goldColor.withOpacity(0.1) : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50]),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: isSelected ? goldColor : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          onTap: () {
                            if (_isSelectAllMode) {
                              _toggleUserSelection(user.id);
                            } else {
                              _openChat(user);
                            }
                          },
                          leading: Stack(
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfileViewScreen(userId: user.id))),
                                child: CircleAvatar(
                                  radius: 25,
                                  backgroundImage: user.profilePic != null ? NetworkImage(user.profilePic!) : null,
                                  child: user.profilePic == null ? const Icon(Icons.person) : null,
                                ),
                              ),
                              if (_isSelectAllMode)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: isSelected ? goldColor : Colors.grey,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isSelected ? Icons.check : Icons.add,
                                      size: 12,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Text(
                            user.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            user.phone ?? user.email,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          trailing: _isSelectAllMode 
                            ? Checkbox(
                                value: isSelected,
                                activeColor: goldColor,
                                onChanged: (val) => _toggleUserSelection(user.id),
                              )
                            : Icon(Icons.chevron_right, color: goldColor),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _isSelectAllMode
          ? FloatingActionButton.extended(
              onPressed: () {
                // Re-fetch or pass users to show dialog
                _adminService.getAllUsers().first.then((users) => _showBroadcastDialog(users));
              },
              backgroundColor: goldColor,
              label: const Text('Message Selected', style: TextStyle(color: Colors.black)),
              icon: const Icon(Icons.send, color: Colors.black),
            )
          : null,
    );
  }

  void _showLongPressMenu(List<UserModel> allUsers) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.select_all),
            title: const Text('Select All Users'),
            onTap: () {
              Navigator.pop(context);
              _selectAllUsers(allUsers);
            },
          ),
          ListTile(
            leading: const Icon(Icons.clear_all),
            title: const Text('Clear Selection'),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _selectedUserIds.clear();
                _isSelectAllMode = false;
              });
            },
          ),
        ],
      ),
    );
  }

  void _openChat(UserModel user) {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) return;

    final chatId = _chatService.getPrivateChatId(adminUid, user.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          rideId: '', // No specific ride for admin support
          destinationName: 'Support',
          privateChatId: chatId,
          otherUserName: user.name,
          otherUserPhotoUrl: user.profilePic,
        ),
      ),
    );
  }
}

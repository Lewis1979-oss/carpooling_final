import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../services/safety_service.dart';
import '../models/user_model.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/appearance_sheet.dart';
import 'account_settings_screen.dart';
import 'payment_screen.dart';
import 'about_screen.dart';
import 'user_manual_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_chat_list_screen.dart';

class MainDrawer extends StatelessWidget {
  const MainDrawer({super.key});

  final String emergencyPhoneNumber = "+260964256282";
  final String appDownloadUrl = "https://zedpool.app/download";

  void _referApp(BuildContext context) {
    final String shareText = "Hey! Check out ZedPool, the easiest way to carpool in Zambia. Download it here: $appDownloadUrl";
    Share.share(shareText, subject: 'Join ZedPool Premium');
  }

  void _showGeneralReportDialog(BuildContext context, Color gold, bool isDark) {
    final controller = TextEditingController();
    final user = FirebaseAuth.instance.currentUser;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: GlassContainer(
          isDark: isDark,
          borderRadius: 20,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.report_problem, color: gold),
                    const SizedBox(width: 10),
                    const Text('Report an Issue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 15),
                const Text('Describe the safety concern or technical issue you are experiencing.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 15),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Type details here...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () async {
                        if (controller.text.isNotEmpty && user != null) {
                          await SafetyService().reportIssue(null, user.uid, controller.text);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Report submitted to Admin.'), behavior: SnackBarBehavior.floating),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black),
                      child: const Text('Submit Report'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthService authService, bool isDark) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          bool isLoggingOut = false;
          
          return AlertDialog(
            backgroundColor: Colors.transparent,
            contentPadding: EdgeInsets.zero,
            content: GlassContainer(
              isDark: isDark,
              borderRadius: 20,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.logout, color: Colors.red, size: 40),
                    const SizedBox(height: 20),
                    const Text('Logout', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    const Text('Are you sure you want to log out of ZedPool?', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 25),
                    if (isLoggingOut)
                      const CircularProgressIndicator(color: Colors.red)
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context), 
                            child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54))
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              setDialogState(() => isLoggingOut = true);
                              try {
                                await authService.signOut();
                                if (context.mounted) {
                                  // Close dialog
                                  Navigator.of(context).pop();
                                  // Reset navigation to root (AuthWrapper) to ensure no sub-screens are left open
                                  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  setDialogState(() => isLoggingOut = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Logout failed. Please try again.'))
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red, 
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                            ),
                            child: const Text('Yes, Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final themeService = Provider.of<ThemeService>(context);
    final user = FirebaseAuth.instance.currentUser;
    final isDark = themeService.isDarkMode;
    final activeGold = themeService.goldAccent;

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: GlassContainer(
        isDark: isDark,
        borderRadius: 0,
        padding: EdgeInsets.zero,
        blur: 30,
        child: Column(
          children: [
            FutureBuilder<UserModel?>(
              future: authService.getUserData(user?.uid ?? ''),
              builder: (context, snapshot) {
                final userData = snapshot.data;
                final isAdmin = userData?.role == 'admin';
                return Column(
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        themeService.setTabIndex(4); // Navigate to Profile Tab
                      },
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.only(
                          top: MediaQuery.of(context).padding.top + 20,
                          left: 20,
                          right: 20,
                          bottom: 20,
                        ),
                        decoration: BoxDecoration(
                          color: activeGold.withOpacity(isDark ? 0.05 : 0.1),
                          border: Border(bottom: BorderSide(color: activeGold.withOpacity(0.2), width: 1)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: activeGold.withOpacity(0.5), width: 2),
                              ),
                              child: CircleAvatar(
                                radius: 30,
                                backgroundColor: activeGold.withOpacity(0.2),
                                backgroundImage: userData?.profilePic != null ? NetworkImage(userData!.profilePic!) : null,
                                child: userData?.profilePic == null ? Icon(Icons.person, color: activeGold, size: 35) : null,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(userData?.name ?? 'User', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
                                  Text(userData?.email ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: activeGold.withOpacity(0.5)),
                          ],
                        ),
                      ),
                    ),
                    if (isAdmin) ...[
                      _buildDrawerItem(
                        icon: Icons.admin_panel_settings,
                        title: 'Admin Dashboard',
                        activeGold: activeGold,
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDashboardScreen()));
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.support_agent,
                        title: 'Support Chats',
                        activeGold: activeGold,
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminChatListScreen()));
                        },
                      ),
                      Divider(color: activeGold.withOpacity(0.2)),
                    ],
                  ],
                );
              },
            ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(icon: Icons.person_outline, title: 'My Profile', activeGold: activeGold, isDark: isDark, onTap: () {
                    Navigator.pop(context);
                    themeService.setTabIndex(4); // Profile Tab
                  }),
                  _buildDrawerItem(icon: Icons.history, title: 'Ride History', activeGold: activeGold, isDark: isDark, onTap: () {
                    Navigator.pop(context);
                    themeService.setTabIndex(3); // My Rides Tab
                  }),
                  _buildDrawerItem(icon: Icons.chat_bubble_outline, title: 'Messages', activeGold: activeGold, isDark: isDark, onTap: () {
                    Navigator.pop(context);
                    themeService.setTabIndex(2); // Inbox Tab
                  }),
                  _buildDrawerItem(icon: Icons.payment, title: 'Payments', activeGold: activeGold, isDark: isDark, onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const PaymentScreen()));
                  }),
                  _buildDrawerItem(icon: Icons.settings_outlined, title: 'Account Settings', activeGold: activeGold, isDark: isDark, onTap: () async {
                    Navigator.pop(context);
                    final userData = await authService.getUserData(user?.uid ?? '');
                    if (userData != null && context.mounted) {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => AccountSettingsScreen(userData: userData)));
                    }
                  }),
                  _buildDrawerItem(icon: Icons.palette_outlined, title: 'Personalize App', activeGold: activeGold, isDark: isDark, onTap: () {
                    Navigator.pop(context);
                    AppearanceSheet.show(context);
                  }),
                  _buildDrawerItem(icon: Icons.menu_book_outlined, title: 'User Manual', activeGold: activeGold, isDark: isDark, onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const UserManualScreen()));
                  }),
                  _buildDrawerItem(icon: Icons.report_outlined, title: 'Report an Issue', activeGold: activeGold, isDark: isDark, onTap: () {
                    Navigator.pop(context);
                    _showGeneralReportDialog(context, activeGold, isDark);
                  }),
                  _buildDrawerItem(icon: Icons.card_giftcard, title: 'Refer & Share', activeGold: activeGold, isDark: isDark, onTap: () => _referApp(context)),
                  _buildDrawerItem(icon: Icons.info_outline, title: 'About ZedPool', activeGold: activeGold, isDark: isDark, onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutScreen()));
                  }),
                ],
              ),
            ),

            Divider(color: activeGold.withOpacity(0.2)),
            _buildDrawerItem(
              icon: Icons.logout, 
              title: 'Logout', 
              activeGold: activeGold, 
              isDark: isDark, 
              textColor: Colors.red, 
              iconColor: Colors.red, 
              onTap: () => _showLogoutDialog(context, authService, isDark),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon, 
    required String title, 
    required VoidCallback onTap, 
    required Color activeGold, 
    required bool isDark,
    Color? textColor, 
    Color? iconColor
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? activeGold).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor ?? activeGold, size: 20),
      ),
      title: Text(
        title, 
        style: TextStyle(
          color: textColor ?? (isDark ? Colors.white : Colors.black87), 
          fontWeight: FontWeight.w600,
          fontSize: 14,
        )
      ),
      onTap: onTap,
    );
  }
}

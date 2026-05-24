import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/theme_service.dart';
import '../services/safety_service.dart';
import '../services/error_service.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/appearance_sheet.dart';
import 'account_settings_screen.dart';
import 'payment_screen.dart';
import 'payment_history_screen.dart';
import 'about_screen.dart';
import 'user_manual_screen.dart';
import 'user_profile_view_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _zedPointsTapCount = 0;
  DateTime? _lastTapTime;
  final String _adminPassword = "admin123";
  bool _isLoading = false;

  final String appDownloadUrl = "https://zedpool.app/download";

  void _handleZedPointsTap() {
    final now = DateTime.now();
    if (_lastTapTime == null || now.difference(_lastTapTime!) > const Duration(seconds: 2)) {
      _zedPointsTapCount = 1;
    } else {
      _zedPointsTapCount++;
    }
    _lastTapTime = now;

    if (_zedPointsTapCount >= 7) {
      _zedPointsTapCount = 0;
      _showPasswordDialog();
    }
  }

  void _referApp() {
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
                const Text('Describe the safety concern or technical issue.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 15),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Type details here...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
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
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted.')));
                        }
                      },
                      child: const Text('Submit'),
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

  void _showPasswordDialog() {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: GlassContainer(
          isDark: true,
          borderRadius: 20,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Admin Access', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text('Enter verification key', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 20),
                TextField(
                  controller: passwordController, 
                  obscureText: true, 
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(hintText: 'Admin Key', hintStyle: TextStyle(color: Colors.grey))
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () {
                        if (passwordController.text == _adminPassword) {
                          Navigator.pop(context);
                          _showAdminAuthDialog();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect verification key')));
                        }
                      },
                      child: const Text('Next'),
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

  void _showAdminAuthDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isAuthenticating = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          content: GlassContainer(
            isDark: true,
            borderRadius: 20,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Official Login', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  const Text('Enter admin credentials to continue', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: emailController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(hintText: 'Admin Email', hintStyle: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(hintText: 'Admin Password', hintStyle: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(height: 25),
                  if (isAuthenticating)
                    const Padding(padding: EdgeInsets.all(10.0), child: CircularProgressIndicator())
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () async {
                            if (emailController.text.isEmpty || passwordController.text.isEmpty) return;
                            
                            setDialogState(() => isAuthenticating = true);
                            try {
                              UserCredential credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
                                email: emailController.text.trim(),
                                password: passwordController.text,
                              );
                              
                              if (credential.user != null) {
                                DocumentSnapshot userDoc = await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(credential.user!.uid)
                                    .get();
                                
                                if (userDoc.exists && (userDoc.data() as Map<String, dynamic>)['role'] == 'admin') {
                                  Navigator.pop(context);
                                  Navigator.pushNamed(context, '/admin');
                                } else {
                                  await FirebaseAuth.instance.signOut();
                                  setDialogState(() => isAuthenticating = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Access Denied: This account is not registered as an Administrator.')),
                                  );
                                }
                              }
                            } catch (e) {
                              setDialogState(() => isAuthenticating = false);
                              final friendlyMessage = ErrorService.getFriendlyMessage(e);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(friendlyMessage)),
                              );
                            }
                          },
                          child: const Text('Login'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDark = themeService.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                const Text('Logout Confirmation', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                const Text('Are you sure you want to log out of ZedPool?', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        authService.signOut();
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final themeService = Provider.of<ThemeService>(context);
    final bool isDark = themeService.isDarkMode;
    final Color goldColor = themeService.goldAccent;

    return GlassScaffold(
      body: StreamBuilder<UserModel?>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots().map((doc) => doc.exists ? UserModel.fromMap(doc.data()!, doc.id) : null),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final userData = snapshot.data;
          
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 110),
                GestureDetector(
                  onTap: () {
                    if (userData != null) {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfileViewScreen(userId: userData.id)));
                    }
                  },
                  child: CircleAvatar(
                    radius: 65,
                    backgroundColor: goldColor.withOpacity(0.1),
                    backgroundImage: userData?.profilePic != null ? NetworkImage(userData!.profilePic!) : null,
                    child: userData?.profilePic == null ? Icon(Icons.person, size: 60, color: goldColor) : null,
                  ),
                ),
                const SizedBox(height: 16),
                Text(userData?.name ?? 'User', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                if (userData?.bio != null && userData!.bio!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      userData.bio!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 14, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(userData?.verificationStatus.toUpperCase() ?? 'UNVERIFIED', style: TextStyle(color: goldColor, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5)),
                
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(child: GestureDetector(onTap: _handleZedPointsTap, child: _buildStatCard('ZedPoints', '${userData?.zedPoints ?? 0}', 'Rewards', goldColor, isDark))),
                    const SizedBox(width: 15),
                    Expanded(child: _buildStatCard('Rating', userData?.averageRating.toStringAsFixed(1) ?? '5.0', '${userData?.ratingCount ?? 0} Reviews', goldColor, isDark)),
                  ],
                ),
                
                const SizedBox(height: 30),
                GlassContainer(
                  isDark: isDark,
                  padding: EdgeInsets.zero,
                  borderRadius: 25,
                  child: Column(
                    children: [
                      _buildMenuItem(Icons.settings_outlined, 'Account Settings', isDark, goldColor, onTap: () {
                        if (userData != null) Navigator.push(context, MaterialPageRoute(builder: (context) => AccountSettingsScreen(userData: userData)));
                      }),
                      _buildMenuItem(Icons.payment, 'Payments', isDark, goldColor, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PaymentScreen()))),
                      _buildMenuItem(Icons.history, 'Payment History', isDark, goldColor, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PaymentHistoryScreen()))),
                      _buildMenuItem(Icons.palette_outlined, 'Appearance', isDark, goldColor, onTap: () => AppearanceSheet.show(context)),
                      _buildMenuItem(Icons.menu_book_outlined, 'User Manual', isDark, goldColor, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UserManualScreen()))),
                      _buildMenuItem(Icons.report_outlined, 'Report an Issue', isDark, goldColor, onTap: () => _showGeneralReportDialog(context, goldColor, isDark)),
                      _buildMenuItem(Icons.card_giftcard, 'Refer & Share', isDark, goldColor, onTap: _referApp),
                      _buildMenuItem(Icons.info_outline, 'About ZedPool', isDark, goldColor, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutScreen()))),
                      _buildMenuItem(Icons.logout, 'Logout', isDark, Colors.red, textColor: Colors.red, onTap: _showLogoutDialog),
                    ],
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, String value, String subValue, Color gold, bool isDark) {
    return GlassContainer(
      isDark: isDark, 
      padding: const EdgeInsets.symmetric(vertical: 20),
      borderRadius: 20,
      child: Column(children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: gold, fontSize: 24, fontWeight: FontWeight.w900)),
        Text(subValue, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ]),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, bool isDark, Color iconColor, {Color? textColor, VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap, 
      leading: Icon(icon, color: iconColor, size: 22),
      title: Text(title, style: TextStyle(color: textColor ?? (isDark ? Colors.white : Colors.black87), fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
    );
  }
}

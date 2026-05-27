import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/safety_report_model.dart';
import '../services/admin_service.dart';
import '../services/safety_service.dart';
import '../services/chat_service.dart';
import '../screens/chat_screen.dart';
import 'glass_widgets.dart';

class AdminUserActionDialog extends StatelessWidget {
  final UserModel user;
  final bool isDark;
  final Color gold;

  const AdminUserActionDialog({
    super.key,
    required this.user,
    required this.isDark,
    required this.gold,
  });

  static void show(BuildContext context, UserModel user, Color gold, bool isDark) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AdminUserActionDialog(user: user, isDark: isDark, gold: gold),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SafetyReportModel>>(
      stream: SafetyService().getSafetyReports(),
      builder: (context, snapshot) {
        final reports = snapshot.data ?? [];
        
        final bool isReportingSOS = reports.any((r) => r.reporterId == user.id && r.isSOS);
        final bool isReportedByOthers = reports.any((r) => r.reportedUserId == user.id);
        
        final bool hasSafetyFlags = isReportingSOS || isReportedByOthers;
        
        final Color statusColor = hasSafetyFlags ? Colors.red : (user.isVerified ? Colors.green : gold);

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            child: GlassContainer(
              isDark: isDark,
              borderRadius: 30,
              accentColor: statusColor,
              borderWidth: 2,
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildProfileHeader(statusColor, isReportingSOS, isReportedByOthers),
                  const SizedBox(height: 16),
                  Text(
                    user.name,
                    style: TextStyle(
                      fontSize: 24, 
                      fontWeight: FontWeight.bold, 
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: 0.5
                    ),
                  ),
                  
                  // Verification Fee Badge
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: user.verificationFeePaid ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: user.verificationFeePaid ? Colors.green : Colors.orange, width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          user.verificationFeePaid ? Icons.check_circle_outline : Icons.pending_outlined, 
                          color: user.verificationFeePaid ? Colors.green : Colors.orange, 
                          size: 14
                        ),
                        const SizedBox(width: 4),
                        Text(
                          user.verificationFeePaid ? "Verification Fee Paid" : "Fee Not Paid",
                          style: TextStyle(
                            color: user.verificationFeePaid ? Colors.green : Colors.orange, 
                            fontSize: 10, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniStat('Rating', user.averageRating.toStringAsFixed(1), Icons.star, Colors.amber),
                      _buildMiniStat('Joined', user.createdAt != null ? DateFormat('MMM yyyy').format(user.createdAt!) : 'N/A', Icons.calendar_today, Colors.blue),
                      _buildMiniStat('ZedPoints', user.zedPoints.toString(), Icons.military_tech, gold),
                    ],
                  ),
                  const SizedBox(height: 32),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'ADMIN MANAGEMENT', 
                      style: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38, 
                        fontSize: 10, 
                        fontWeight: FontWeight.w900, 
                        letterSpacing: 2
                      )
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildActionTile(
                    context,
                    label: user.isVerified ? 'Verified Account' : 'Verify Identity',
                    icon: Icons.verified_user,
                    color: user.isVerified ? Colors.green : Colors.blue,
                    onTap: () async {
                      await AdminService().updateVerificationStatus(user.id, user.isVerified ? 'unverified' : 'verified');
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                  
                  _buildActionTile(
                    context,
                    label: 'Send Direct Message',
                    icon: Icons.chat_bubble_outline,
                    color: gold,
                    onTap: () {
                      final adminId = FirebaseAuth.instance.currentUser?.uid;
                      if (adminId != null) {
                        final chatId = ChatService().getPrivateChatId(adminId, user.id);
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(
                          rideId: '',
                          destinationName: 'Support',
                          privateChatId: chatId,
                          otherUserName: user.name,
                          otherUserPhotoUrl: user.profilePic,
                          isWithAdmin: true,
                        )));
                      }
                    },
                  ),
                  
                  _buildActionTile(
                    context,
                    label: user.isBlocked ? 'Reactivate Account' : 'Suspend Account',
                    icon: user.isBlocked ? Icons.lock_open : Icons.block,
                    color: Colors.redAccent,
                    onTap: () async {
                      bool? confirm = await _showConfirmAction(
                        context, 
                        user.isBlocked ? 'Unblock User?' : 'Block User?', 
                        'Are you sure you want to ${user.isBlocked ? 'unblock' : 'suspend'} ${user.name}?'
                      );
                      if (confirm == true) {
                        await AdminService().setUserBlockStatus(user.id, !user.isBlocked);
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'CLOSE', 
                      style: TextStyle(
                        color: isDark ? Colors.white30 : Colors.black38, 
                        fontWeight: FontWeight.w900, 
                        letterSpacing: 1
                      )
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

  Widget _buildProfileHeader(Color statusColor, bool inDanger, bool reported) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: statusColor.withOpacity(0.5), width: 2),
            boxShadow: [
              BoxShadow(color: statusColor.withOpacity(0.2), blurRadius: 15, spreadRadius: 2)
            ]
          ),
          child: CircleAvatar(
            radius: 48,
            backgroundColor: statusColor.withOpacity(0.1),
            backgroundImage: user.profilePic != null ? NetworkImage(user.profilePic!) : null,
            child: user.profilePic == null ? Icon(Icons.person, size: 40, color: statusColor) : null,
          ),
        ),
        if (inDanger || reported)
          Positioned(
            bottom: 4, right: 4,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              child: Icon(inDanger ? Icons.emergency : Icons.warning_rounded, color: Colors.white, size: 18),
            ),
          ),
        if (user.isVerified && !inDanger && !reported)
          Positioned(
            bottom: 4, right: 4,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 18),
            ),
          ),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildActionTile(BuildContext context, {required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 14),
                Text(
                  label, 
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)
                ),
                const Spacer(),
                Icon(Icons.chevron_right, color: color.withOpacity(0.3), size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _showConfirmAction(BuildContext context, String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: GlassContainer(
          isDark: isDark,
          borderRadius: 25,
          accentColor: Colors.red,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.help_outline, color: Colors.red, size: 40),
              const SizedBox(height: 16),
              Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false), 
                    child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true), 
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red, 
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                    child: const Text('CONFIRM', style: TextStyle(fontWeight: FontWeight.bold))
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

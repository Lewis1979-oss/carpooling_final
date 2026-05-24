import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'glass_widgets.dart';

class CallChoiceDialog extends StatelessWidget {
  final UserModel otherUser;
  final VoidCallback onCellularCall;
  final VoidCallback onZedPoolCall;
  final Color gold;
  final bool isDark;

  const CallChoiceDialog({
    super.key,
    required this.otherUser,
    required this.onCellularCall,
    required this.onZedPoolCall,
    required this.gold,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // If phone number is hidden, we might want to inform the user or just hide the option
    final bool canShowCellular = otherUser.phone != null && !otherUser.hidePhoneNumber;

    return AlertDialog(
      backgroundColor: Colors.transparent,
      contentPadding: EdgeInsets.zero,
      content: GlassContainer(
        isDark: isDark,
        borderRadius: 25,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: gold.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: gold.withOpacity(0.3)),
              ),
              child: Icon(Icons.phone_forwarded_rounded, color: gold, size: 30),
            ),
            const SizedBox(height: 20),
            Text(
              "Call ${otherUser.name.split(' ').first}?",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Choose your preferred calling method",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 30),
            
            // Option 1: ZedPool Call (Agora)
            _buildCallOption(
              icon: Icons.wifi_calling_3_rounded,
              label: "ZedPool In-App Call",
              sub: "Free via Data / Wi-Fi",
              color: gold,
              onTap: () {
                Navigator.pop(context);
                onZedPoolCall();
              },
            ),
            
            if (canShowCellular) ...[
              const SizedBox(height: 12),
              
              // Option 2: Cellular Call
              _buildCallOption(
                icon: Icons.settings_phone_rounded,
                label: "Normal Phone Call",
                sub: "Standard Network Rates",
                color: Colors.white70,
                onTap: () {
                  Navigator.pop(context);
                  onCellularCall();
                },
              ),
            ] else if (otherUser.hidePhoneNumber) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  "Phone number hidden for privacy",
                  style: TextStyle(color: Colors.redAccent.withOpacity(0.6), fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ),
            ],
            
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: Colors.redAccent.withOpacity(0.8))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallOption({
    required IconData icon,
    required String label,
    required String sub,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color.withOpacity(0.5), size: 12),
          ],
        ),
      ),
    );
  }
}

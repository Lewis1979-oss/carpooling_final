import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/voice_call_service.dart';
import '../widgets/glass_widgets.dart';

class CallScreen extends StatelessWidget {
  const CallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final callService = Provider.of<VoiceCallService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final remoteUser = callService.remoteUser;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient/Blur
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).primaryColor.withOpacity(0.8),
                  Colors.black,
                ],
              ),
            ),
          ),
          
          // User Info
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).primaryColor, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundImage: remoteUser?.profilePic != null 
                          ? NetworkImage(remoteUser!.profilePic!) 
                          : null,
                      child: remoteUser?.profilePic == null 
                          ? const Icon(Icons.person, size: 60) 
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  remoteUser?.name ?? "Unknown User",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  callService.callStatus == CallStatus.dialling 
                      ? "Dialling..." 
                      : (callService.callStatus == CallStatus.ringing ? "Ringing..." : "Connected"),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                
                // Call Controls
                GlassContainer(
                  isDark: true,
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  borderRadius: 30,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildControlButton(
                        icon: callService.isMuted ? Icons.mic_off : Icons.mic,
                        label: "Mute",
                        onPressed: () => callService.toggleMute(),
                        isActive: callService.isMuted,
                      ),
                      _buildControlButton(
                        icon: Icons.call_end,
                        label: "End",
                        onPressed: () {
                          callService.endCall();
                          Navigator.pop(context);
                        },
                        color: Colors.red,
                      ),
                      _buildControlButton(
                        icon: callService.isSpeaker ? Icons.volume_up : Icons.volume_down,
                        label: "Speaker",
                        onPressed: () => callService.toggleSpeaker(),
                        isActive: callService.isSpeaker,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
    bool isActive = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isActive ? Colors.white.withOpacity(0.2) : (color ?? Colors.white.withOpacity(0.1)),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

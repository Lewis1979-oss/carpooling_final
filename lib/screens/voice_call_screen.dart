import 'dart:ui';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/voice_call_service.dart';
import '../widgets/glass_widgets.dart';

class VoiceCallScreen extends StatefulWidget {
  final UserModel caller;
  final String channelId;
  final String token;
  final bool isIncoming;

  const VoiceCallScreen({
    super.key,
    required this.caller,
    required this.channelId,
    required this.token,
    this.isIncoming = false,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  StreamSubscription? _statusSubscription;

  @override
  void initState() {
    super.initState();
    final callService = Provider.of<VoiceCallService>(context, listen: false);
    
    if (widget.isIncoming) {
      callService.startRinging();
      _listenForCallStatus();
    }
  }

  void _listenForCallStatus() {
    // Listen to the signaling document to detect if the caller hung up
    _statusSubscription = FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.channelId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists || snapshot.data()?['status'] == 'ended' || snapshot.data()?['status'] == 'rejected') {
        if (mounted) {
          Provider.of<VoiceCallService>(context, listen: false).stopRinging();
          Navigator.of(context).pop();
        }
      }
    });
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callService = Provider.of<VoiceCallService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final remoteUser = widget.isIncoming ? widget.caller : callService.remoteUser;

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
                  widget.isIncoming && callService.callStatus == CallStatus.idle
                      ? "Incoming Call..."
                      : (callService.callStatus == CallStatus.dialling 
                          ? "Dialling..." 
                          : (callService.callStatus == CallStatus.ringing ? "Ringing..." : "Connected")),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                
                // Call Controls
                if (widget.isIncoming && callService.callStatus == CallStatus.idle)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 50),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildCallAction(
                          icon: Icons.call_end,
                          label: "Decline",
                          color: Colors.red,
                          onPressed: () {
                            callService.rejectCall({
                              'channelId': widget.channelId,
                              'callerId': widget.caller.id,
                            });
                            Navigator.pop(context);
                          },
                        ),
                        _buildCallAction(
                          icon: Icons.call,
                          label: "Accept",
                          color: Colors.green,
                          onPressed: () {
                            callService.acceptCall({
                              'channelId': widget.channelId,
                              'callerId': widget.caller.id,
                            });
                          },
                        ),
                      ],
                    ),
                  )
                else
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

  Widget _buildCallAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 5,
                )
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

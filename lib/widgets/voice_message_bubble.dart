import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:async';

class VoiceMessageBubble extends StatefulWidget {
  final String url;
  final int? duration;
  final bool isMe;
  final Color gold;

  const VoiceMessageBubble({
    super.key,
    required this.url,
    this.duration,
    required this.isMe,
    required this.gold,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  late PlayerController controller;
  late StreamSubscription<PlayerState> playerStateSubscription;
  bool isPlaying = false;
  bool isPreparing = true;
  String? localPath;

  @override
  void initState() {
    super.initState();
    controller = PlayerController();
    _initPlayer();
    playerStateSubscription = controller.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          isPlaying = state == PlayerState.playing;
        });
      }
    });
  }

  Future<void> _initPlayer() async {
    try {
      if (widget.url.startsWith('http')) {
        // Download network file to local cache
        final directory = await getTemporaryDirectory();
        // Create a safe filename from the URL
        final fileName = widget.url.split('/').last.split('?').first;
        final file = File('${directory.path}/$fileName');

        if (!await file.exists()) {
          final response = await http.get(Uri.parse(widget.url));
          await file.writeAsBytes(response.bodyBytes);
        }
        localPath = file.path;
      } else {
        localPath = widget.url;
      }

      await controller.preparePlayer(
        path: localPath!,
        shouldExtractWaveform: true,
        noOfSamples: 50,
        volume: 1.0,
      );
      if (mounted) setState(() => isPreparing = false);
    } catch (e) {
      debugPrint("Error preparing voice player: $e");
      if (mounted) setState(() => isPreparing = false);
    }
  }

  @override
  void dispose() {
    playerStateSubscription.cancel();
    controller.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    int mins = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return "$mins:${remainingSeconds.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isMe ? Colors.black : widget.gold;

    if (isPreparing) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          ),
          const SizedBox(width: 12),
          Text('Loading audio...', style: TextStyle(fontSize: 11, color: widget.isMe ? Colors.black54 : Colors.grey)),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () async {
            if (isPlaying) {
              await controller.pausePlayer();
            } else {
              await controller.startPlayer();
            }
          },
          icon: Icon(
            isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
            color: color,
            size: 32,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 8),
        AudioFileWaveforms(
          size: const Size(120, 30),
          playerController: controller,
          enableSeekGesture: true,
          waveformType: WaveformType.fitWidth,
          playerWaveStyle: PlayerWaveStyle(
            fixedWaveColor: color.withOpacity(0.3),
            liveWaveColor: color,
            spacing: 6,
            waveThickness: 3,
            seekLineColor: Colors.red,
            seekLineThickness: 2,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          widget.duration != null ? _formatDuration(widget.duration!) : '0:00',
          style: TextStyle(fontSize: 11, color: widget.isMe ? Colors.black54 : Colors.grey),
        ),
      ],
    );
  }
}

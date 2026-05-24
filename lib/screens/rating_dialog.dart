import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/rating_model.dart';
import '../services/rating_service.dart';
import '../services/theme_service.dart';
import '../widgets/glass_widgets.dart';

class RatingDialog extends StatefulWidget {
  final String rideId;
  final String revieweeId;
  final String revieweeName;

  const RatingDialog({
    super.key,
    required this.rideId,
    required this.revieweeId,
    required this.revieweeName,
  });

  @override
  _RatingDialogState createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  // Expert Fix: Initialized to 0.0 so user MUST pick a rating
  double _rating = 0.0;
  final _commentController = TextEditingController();
  final _ratingService = RatingService();

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;
    final activeGold = isDark ? const Color(0xFFD4AF37) : const Color(0xFFC0A060);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassContainer(
        isDark: isDark,
        borderRadius: 24,
        accentColor: activeGold,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: activeGold.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.star_rounded, color: activeGold, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              'Rate your trip',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'How was your ride with ${widget.revieweeName}?',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    index < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 42, // Slightly larger for easier tapping
                    color: index < _rating ? activeGold : Colors.grey.withOpacity(0.3),
                  ),
                  onPressed: () {
                    setState(() {
                      _rating = index + 1.0;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 24),
            GlassContainer(
              padding: EdgeInsets.zero,
              borderRadius: 16,
              isDark: isDark,
              accentColor: activeGold,
              blur: 10,
              child: TextField(
                controller: _commentController,
                maxLines: 3,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Share your experience...',
                  hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'NOT NOW',
                      style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _rating == 0.0 ? null : () async {
                      final currentUser = FirebaseAuth.instance.currentUser;
                      if (currentUser != null) {
                        final rating = RatingModel(
                          id: '',
                          rideId: widget.rideId,
                          reviewerId: currentUser.uid,
                          revieweeId: widget.revieweeId,
                          rating: _rating,
                          comment: _commentController.text.trim(),
                          timestamp: DateTime.now(),
                        );
                        await _ratingService.submitRating(rating);
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Thank you for your feedback!'), behavior: SnackBarBehavior.floating),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: activeGold,
                      disabledBackgroundColor: activeGold.withOpacity(0.2),
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text('SUBMIT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

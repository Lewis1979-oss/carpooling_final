import 'dart:ui';
import 'package:flutter/material.dart';
import 'glass_widgets.dart';

class CustomErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? reassurance;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final String primaryActionLabel;
  final VoidCallback onPrimaryAction;

  const CustomErrorDialog({
    super.key,
    required this.title,
    required this.message,
    this.reassurance,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.primaryActionLabel = 'Try Again',
    required this.onPrimaryAction,
  });

  static void show({
    required BuildContext context,
    required String title,
    required String message,
    String? reassurance,
    String? secondaryActionLabel,
    VoidCallback? onSecondaryAction,
    String primaryActionLabel = 'Try Again',
    required VoidCallback onPrimaryAction,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => CustomErrorDialog(
        title: title,
        message: message,
        reassurance: reassurance,
        secondaryActionLabel: secondaryActionLabel,
        onSecondaryAction: onSecondaryAction,
        primaryActionLabel: primaryActionLabel,
        onPrimaryAction: onPrimaryAction,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color goldColor = isDark ? const Color(0xFFD4AF37) : const Color(0xFFC0A060);
    final Color errorColor = Colors.redAccent;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: GlassContainer(
          isDark: isDark,
          borderRadius: 25,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey[500], size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontFamily: 'Montserrat',
                  ),
                  children: [
                    if (reassurance != null)
                      TextSpan(
                        text: '$reassurance ',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    TextSpan(text: message),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (secondaryActionLabel != null)
                    TextButton(
                      onPressed: onSecondaryAction ?? () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: errorColor,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: errorColor.withOpacity(0.5)),
                        ),
                      ),
                      child: Text(
                        secondaryActionLabel!,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: onPrimaryAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: errorColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      primaryActionLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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

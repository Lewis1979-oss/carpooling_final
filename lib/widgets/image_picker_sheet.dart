import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'glass_widgets.dart';

class ImagePickerSheet extends StatelessWidget {
  final Function(ImageSource) onSourceSelected;
  final Color gold;
  final bool isDark;

  const ImagePickerSheet({
    super.key,
    required this.onSourceSelected,
    required this.gold,
    required this.isDark,
  });

  static void show(BuildContext context, {required Function(ImageSource) onSourceSelected, required Color gold, required bool isDark}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ImagePickerSheet(
        onSourceSelected: onSourceSelected,
        gold: gold,
        isDark: isDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      isDark: isDark,
      borderRadius: 30,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: gold.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 25),
          Text(
            'SELECT IMAGE SOURCE',
            style: TextStyle(
              color: gold,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 30),
          _buildOption(
            icon: Icons.camera_alt_rounded,
            label: 'Take a New Photo',
            sub: 'Use your camera to capture now',
            onTap: () {
              Navigator.pop(context);
              onSourceSelected(ImageSource.camera);
            },
          ),
          const SizedBox(height: 12),
          _buildOption(
            icon: Icons.photo_library_rounded,
            label: 'Choose from Gallery',
            sub: 'Pick an image from your device',
            onTap: () {
              Navigator.pop(context);
              onSourceSelected(ImageSource.gallery);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String label,
    required String sub,
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
          border: Border.all(color: gold.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: gold.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: gold, size: 24),
            ),
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
            Icon(Icons.arrow_forward_ios, color: gold.withOpacity(0.3), size: 12),
          ],
        ),
      ),
    );
  }
}

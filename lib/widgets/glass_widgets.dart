import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final double borderRadius;
  final double blur;
  final double borderOpacity;
  final double containerOpacity;
  final double borderWidth;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool isDark;
  final Color? accentColor;
  final DecorationImage? backgroundImage;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.borderRadius = 25,
    this.blur = 20, 
    this.borderOpacity = 0.15, 
    this.containerOpacity = 0.08, 
    this.borderWidth = 1.0, 
    this.padding,
    this.margin,
    required this.isDark,
    this.accentColor,
    this.backgroundImage,
  });

  @override
  Widget build(BuildContext context) {
    final Color effectiveAccent = accentColor ?? const Color(0xFFD4AF37);

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: -5,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          children: [
            // 1. The Glass Effect (Blur + Overlay Color)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark 
                        ? Colors.white.withOpacity(containerOpacity)
                        : Colors.white.withOpacity(containerOpacity > 0.5 ? 0.3 : containerOpacity),
                    borderRadius: BorderRadius.circular(borderRadius),
                    border: Border.all(
                      color: effectiveAccent.withOpacity(borderOpacity),
                      width: borderWidth, 
                    ),
                  ),
                ),
              ),
            ),

            // 2. The Background Image
            if (backgroundImage != null)
              Positioned.fill(
                child: Opacity(
                  opacity: backgroundImage!.opacity,
                  child: Image(
                    image: backgroundImage!.image,
                    fit: backgroundImage!.fit ?? BoxFit.cover,
                    alignment: backgroundImage!.alignment,
                  ),
                ),
              ),
            
            // 3. The Content
            Container(
              width: width ?? double.infinity, // Ensure it tries to fill width if not specified
              height: height,
              padding: padding ?? const EdgeInsets.all(24),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class GlassScaffold extends StatelessWidget {
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;
  final PreferredSizeWidget? appBar;
  final Widget? drawer;
  final bool extendBodyBehindAppBar;

  const GlassScaffold({
    super.key,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.appBar,
    this.drawer,
    this.extendBodyBehindAppBar = true,
  });

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    
    return Scaffold(
      backgroundColor: themeService.primaryColor,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: appBar,
      drawer: drawer,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: themeService.backgroundGradient,
        ),
        child: body,
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      bottomSheet: bottomSheet,
    );
  }
}

class PremiumSOSButton extends StatelessWidget {
  final VoidCallback onTap;
  const PremiumSOSButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.withOpacity(0.5), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.phone, color: Colors.red, size: 16),
            SizedBox(width: 4),
            Text(
              'SOS',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

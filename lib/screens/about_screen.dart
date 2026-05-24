import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../widgets/glass_widgets.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;
    final themeAccent = themeService.goldAccent;

    return GlassScaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'About ZedPool',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
            fontFamily: themeService.fontFamily,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: themeAccent, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 120),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  Center(
                    child: _buildIconFront(themeAccent),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Text Section
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'ZedPool ',
                          style: TextStyle(
                            fontSize: 28 * themeService.fontSizeFactor, 
                            fontWeight: FontWeight.bold, 
                            letterSpacing: 1,
                            fontFamily: themeService.fontFamily,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        TextSpan(
                          text: 'Premium',
                          style: TextStyle(
                            fontSize: 28 * themeService.fontSizeFactor, 
                            fontWeight: FontWeight.bold, 
                            letterSpacing: 1,
                            fontFamily: themeService.fontFamily,
                            color: themeAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'VERSION 1.0.1',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey, 
                      fontSize: 12 * themeService.fontSizeFactor, 
                      fontWeight: FontWeight.bold, 
                      letterSpacing: 2,
                      fontFamily: themeService.fontFamily,
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  _buildInfoCard(
                    context,
                    'Our Mission',
                    'ZedPool is dedicated to making commuting affordable, safe, and eco-friendly. We connect drivers with empty seats to passengers traveling the same way.',
                    isDark,
                    themeAccent,
                    themeService,
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    context,
                    'Safety First',
                    'With real-time tracking, SOS features, and verified profiles, we ensure your journey is as secure as it is comfortable.',
                    isDark,
                    themeAccent,
                    themeService,
                  ),
                  
                  const SizedBox(height: 50),
                  
                  Text(
                    '© 2026 ZedPool Inc.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey, 
                      fontSize: 11 * themeService.fontSizeFactor, 
                      fontWeight: FontWeight.bold,
                      fontFamily: themeService.fontFamily,
                    ),
                  ),
                  Text(
                    'ALL RIGHTS RESERVED',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey, 
                      fontSize: 9 * themeService.fontSizeFactor, 
                      letterSpacing: 1,
                      fontFamily: themeService.fontFamily,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconFront(Color accent) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: accent.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(color: accent.withOpacity(0.1), blurRadius: 20, spreadRadius: 5)
        ],
      ),
      child: Image.asset(
        'assets/icon/app_icon.png',
        width: 100,
        height: 100,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Icon(Icons.directions_car, color: accent, size: 100),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String title, String body, bool isDark, Color accent, ThemeService theme) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      borderRadius: 25,
      isDark: isDark,
      accentColor: accent,
      containerOpacity: 0.1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: accent, 
              fontWeight: FontWeight.bold, 
              fontSize: 18 * theme.fontSizeFactor,
              fontFamily: theme.fontFamily,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: TextStyle(
              fontSize: 14 * theme.fontSizeFactor, 
              height: 1.6, 
              color: isDark ? Colors.white70 : Colors.black87,
              fontFamily: theme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

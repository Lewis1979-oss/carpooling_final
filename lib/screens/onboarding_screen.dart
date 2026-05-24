import 'package:flutter/material.dart';
import '../widgets/glass_widgets.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinished;
  const OnboardingScreen({super.key, required this.onFinished});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: 'ZedPool Carpooling',
      description: 'Experience a new way of commuting with our carpooling service. Save time and travel efficiently.',
      icon: Icons.directions_car_filled,
      color: const Color(0xFFC0A060),
    ),
    OnboardingData(
      title: 'Easy Booking',
      description: 'Search for rides on the map, view routes, and book your seat in just a few taps. It\'s that simple.',
      icon: Icons.map_outlined,
      color: const Color(0xFFD4AF37),
    ),
    OnboardingData(
      title: 'Voice-Activated SOS',
      description: 'Your safety is our priority. Say "Send Help" anytime to trigger an SOS. We\'ll record 10s of audio and alert Admin & your emergency contact with your location.',
      icon: Icons.record_voice_over,
      color: Colors.redAccent,
    ),
    OnboardingData(
      title: 'Safe & Reliable',
      description: 'Every driver is verified. You can also triple-press the volume buttons to trigger a silent SOS if you\'re in danger.',
      icon: Icons.security,
      color: const Color(0xFFC0A060),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    const Color goldColor = Color(0xFFC0A060);

    return GlassScaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              return _buildPage(_pages[index]);
            },
          ),
          
          // Navigation Controls
          Positioned(
            bottom: 50,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Indicators
                Row(
                  children: List.generate(
                    _pages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(right: 8),
                      height: 8,
                      width: _currentPage == index ? 24 : 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index ? goldColor : Colors.grey.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                
                // Next/Get Started Button
                ElevatedButton(
                  onPressed: () {
                    if (_currentPage < _pages.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.ease,
                      );
                    } else {
                      widget.onFinished();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: goldColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: Text(
                    _currentPage == _pages.length - 1 ? 'GET STARTED' : 'NEXT',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          
          // Skip Button
          if (_currentPage < _pages.length - 1)
            Positioned(
              top: 60,
              right: 24,
              child: TextButton(
                onPressed: widget.onFinished,
                child: const Text('SKIP', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPage(OnboardingData data) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GlassContainer(
            isDark: true,
            borderRadius: 100,
            padding: const EdgeInsets.all(40),
            accentColor: data.color,
            child: Icon(data.icon, size: 100, color: data.color),
          ),
          const SizedBox(height: 60),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  OnboardingData({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

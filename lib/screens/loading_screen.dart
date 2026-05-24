import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/glass_widgets.dart';
import '../services/theme_service.dart';

class LoadingScreen extends StatefulWidget {
  final String message;
  const LoadingScreen({super.key, this.message = 'Getting things ready...'});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: -50, end: 50).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;
    final goldColor = themeService.goldAccent;

    return GlassScaffold(
      body: Center(
        child: GlassContainer(
          isDark: isDark,
          accentColor: goldColor,
          borderRadius: 30,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_animation.value, 0),
                    child: Icon(
                      Icons.directions_car,
                      size: 80,
                      color: goldColor,
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              Container(
                width: 150,
                height: 2,
                color: goldColor.withOpacity(0.2),
                child: Stack(
                  children: [
                    AnimatedBuilder(
                      animation: _animation,
                      builder: (context, child) {
                        return Positioned(
                          left: _animation.value + 75,
                          child: Container(
                            width: 20,
                            height: 2,
                            color: goldColor,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.blueGrey,
                  fontSize: 16,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

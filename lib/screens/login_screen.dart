import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../services/form_validator.dart';
import '../services/error_service.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/custom_dialogs.dart';
import '../main.dart'; 
import 'register_screen.dart';
import 'phone_login_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with RouteAware, WidgetsBindingObserver {
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeVideo();
  }

  void _initializeVideo() {
    _videoController = VideoPlayerController.asset('assets/videos/car_turntable.mp4')
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isVideoInitialized = true;
          });
          _videoController.setLooping(true);
          _videoController.setVolume(0);
          _videoController.play();
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final modalRoute = ModalRoute.of(context);
    if (modalRoute is PageRoute) {
      routeObserver.subscribe(this, modalRoute);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _videoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!_isVideoInitialized) return;

    if (state == AppLifecycleState.resumed) {
      _videoController.play();
    } else {
      _videoController.pause();
    }
  }

  @override
  void didPushNext() {
    if (_isVideoInitialized) {
      _videoController.pause();
    }
  }

  @override
  void didPopNext() {
    if (_isVideoInitialized) {
      _videoController.play();
    }
  }

  void _showForgotPasswordDialog() {
    final authService = AuthService();
    final resetController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: GlassContainer(
          isDark: true,
          borderRadius: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Reset Password', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: resetController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Enter your email',
                  hintStyle: TextStyle(color: Colors.white54),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  ElevatedButton(
                    onPressed: () async {
                      if (FormValidator.isValidEmail(resetController.text.trim())) {
                        try {
                          await authService.sendPasswordResetEmail(resetController.text.trim());
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Password reset email sent! Check your inbox.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            Navigator.pop(context);
                            _handleAuthError(e, 'Reset Password Failed');
                          }
                        }
                      }
                    },
                    child: const Text('Send Reset Link'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;
    final goldColor = themeService.goldAccent;
    final primaryColor = themeService.primaryColor;

    return Scaffold(
      backgroundColor: primaryColor,
      body: Stack(
        children: [
          // Background Video
          if (_isVideoInitialized)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController.value.size.width,
                  height: _videoController.value.size.height,
                  child: VideoPlayer(_videoController),
                ),
              ),
            )
          else
            Container(color: primaryColor),

          // Dynamic Theme-based Gradient Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  primaryColor.withOpacity(0.4),
                  primaryColor.withOpacity(0.7),
                  primaryColor.withOpacity(0.9),
                ],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  // Logo Section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            const TextSpan(
                              text: 'ZED',
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 4,
                              ),
                            ),
                            TextSpan(
                              text: 'POOL',
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                                color: goldColor,
                                letterSpacing: 4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'YOUR PREMIUM CARPOOL',
                        style: TextStyle(
                          fontSize: 14,
                          letterSpacing: 2,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(height: 2, width: 40, color: goldColor),
                    ],
                  ),

                  const SizedBox(height: 50),

                  // Hero Text Section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'RIDE TOGETHER.',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        'SAVE MORE.',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: goldColor,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Carpool now. Save the future.',
                        style: TextStyle(color: Colors.white70, fontSize: 15),
                      ),
                      Text(
                        'Better together.',
                        style: TextStyle(color: goldColor.withOpacity(0.8), fontSize: 15),
                      ),
                    ],
                  ),

                  const SizedBox(height: 45),

                  // Dark semi-transparent input fields with gold borders
                  _buildInputField(
                    controller: _emailController,
                    hintText: 'Email',
                    icon: Icons.email_outlined,
                    accentColor: goldColor,
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _passwordController,
                    hintText: 'Password',
                    icon: Icons.lock_outline,
                    accentColor: goldColor,
                    obscureText: !_isPasswordVisible,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        color: goldColor.withOpacity(0.7),
                        size: 20,
                      ),
                      onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                    ),
                  ),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showForgotPasswordDialog,
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(color: goldColor, fontWeight: FontWeight.w500, fontSize: 13),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Solid gold action button with arrow icon
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: goldColor,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.black, strokeWidth: 2)
                          : Stack(
                              alignment: Alignment.center,
                              children: [
                                const Align(
                                  alignment: Alignment.center,
                                  child: Text(
                                    'LOGIN',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                                  ),
                                ),
                                const Align(
                                  alignment: Alignment.centerRight,
                                  child: Icon(Icons.arrow_forward, size: 20),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white.withOpacity(0.15))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.white.withOpacity(0.15))),
                    ],
                  ),

                  const SizedBox(height: 32),

                  _buildSocialButton(
                    onTap: _handleGoogleSignIn,
                    icon: Image.network(
                      'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_\"G\"_logo.svg/1200px-Google_\"G\"_logo.svg.png',
                      height: 20,
                    ),
                    label: 'CONTINUE WITH GOOGLE',
                  ),
                  const SizedBox(height: 12),
                  _buildSocialButton(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PhoneLoginScreen()),
                      );
                    },
                    icon: Icon(Icons.phone_android, color: goldColor, size: 20),
                    label: 'LOGIN WITH PHONE',
                  ),

                  const SizedBox(height: 40),

                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have an account? ", style: TextStyle(color: Colors.white70)),
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen())),
                          child: Text(
                            'REGISTER',
                            style: TextStyle(color: goldColor, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 50),

                  // Bottom Trust Badges
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTrustBadge(Icons.verified_user_outlined, 'Verified Drivers', goldColor),
                      _buildTrustBadge(Icons.credit_card, 'Secure Payments', goldColor),
                      _buildTrustBadge(Icons.headset_mic_outlined, '24/7 Support', goldColor),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required Color accentColor,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: accentColor.withOpacity(0.4), width: 1),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
          prefixIcon: Icon(icon, color: accentColor, size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
        ),
      ),
    );
  }

  Widget _buildSocialButton({required VoidCallback onTap, required Widget icon, required String label}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          color: Colors.black.withOpacity(0.1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustBadge(IconData icon, String label, Color accentColor) {
    return Column(
      children: [
        Icon(icon, color: accentColor, size: 28),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showFriendlyError('Fields Missing', 'Please enter your credentials.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await AuthService().signIn(email, password);
    } catch (e) {
      _handleAuthError(e, 'Login Failed');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await AuthService().signInWithGoogle();
    } catch (e) {
      _handleAuthError(e, 'Google Sign-In Failed');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleAuthError(dynamic e, String title) {
    if (mounted) {
      final friendlyMessage = ErrorService.getFriendlyMessage(e);
      CustomErrorDialog.show(context: context, title: title, message: friendlyMessage, onPrimaryAction: () => Navigator.pop(context));
    }
  }

  void _showFriendlyError(String title, String message) {
    CustomErrorDialog.show(context: context, title: title, message: message, onPrimaryAction: () => Navigator.pop(context));
  }
}

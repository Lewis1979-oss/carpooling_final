import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../services/form_validator.dart';
import '../services/error_service.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/custom_dialogs.dart';
import '../widgets/image_picker_sheet.dart';
import 'phone_login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with WidgetsBindingObserver {
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;
  
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  
  File? _imageFile;
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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _videoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _emergencyContactController.dispose();
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

  void _showImageSourceAction() {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    ImagePickerSheet.show(
      context,
      gold: themeService.goldAccent,
      isDark: themeService.isDarkMode,
      onSourceSelected: (source) => _pickImage(source),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 50);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final goldColor = themeService.goldAccent;
    final isTealTheme = themeService.appTheme == AppTheme.tealGold;

    return Scaffold(
      backgroundColor: themeService.primaryColor,
      body: Stack(
        children: [
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
            Container(color: isTealTheme ? const Color(0xFF0D3B3B) : const Color(0xFF0A0E14)),

          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  (isTealTheme ? const Color(0xFF0D3B3B) : Colors.black).withOpacity(0.4),
                  (isTealTheme ? const Color(0xFF0D3B3B) : Colors.black).withOpacity(0.7),
                  (isTealTheme ? const Color(0xFF0D3B3B) : Colors.black).withOpacity(0.9),
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
                  _buildLogo(goldColor, isTealTheme),
                  const SizedBox(height: 30),
                  
                  const Text(
                    'RIDE TOGETHER.',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
                  ),
                  Text(
                    'SAVE MORE.',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: goldColor, letterSpacing: 1),
                  ),
                  const SizedBox(height: 12),
                  const Text('Create your ZedPool account today.', style: TextStyle(color: Colors.white70, fontSize: 15)),
                  
                  const SizedBox(height: 30),
                  _buildProfilePicker(goldColor),
                  const SizedBox(height: 30),

                  _buildInputField(controller: _nameController, hintText: 'Full Name', icon: Icons.person_outline, accentColor: goldColor),
                  const SizedBox(height: 16),
                  _buildInputField(controller: _emailController, hintText: 'Email', icon: Icons.email_outlined, accentColor: goldColor, keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _passwordController,
                    hintText: 'Password',
                    icon: Icons.lock_outline,
                    accentColor: goldColor,
                    obscureText: !_isPasswordVisible,
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: goldColor.withOpacity(0.7), size: 20),
                      onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(controller: _emergencyContactController, hintText: 'Emergency Contact (+260...)', icon: Icons.contact_phone_outlined, accentColor: goldColor, keyboardType: TextInputType.phone),

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: goldColor,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.black)
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text('REGISTER', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward, size: 20),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 40),
                  _buildLoginLink(goldColor),
                  const SizedBox(height: 50),
                  
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

  Widget _buildLogo(Color goldColor, bool isTealTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              const TextSpan(text: 'ZED', style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 4)),
              TextSpan(text: 'POOL', style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: goldColor, letterSpacing: 4)),
            ],
          ),
        ),
        Text('YOUR PREMIUM CARPOOL', style: TextStyle(fontSize: 14, letterSpacing: 2, color: isTealTheme ? const Color(0xFFA7F3E6).withOpacity(0.7) : Colors.white70)),
        const SizedBox(height: 8),
        Container(height: 2, width: 40, color: goldColor),
      ],
    );
  }

  Widget _buildProfilePicker(Color goldColor) {
    return Center(
      child: GestureDetector(
        onTap: _showImageSourceAction,
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: goldColor.withOpacity(0.5), width: 2)),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white.withOpacity(0.05),
                backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                child: _imageFile == null ? Icon(Icons.person_outline, size: 50, color: goldColor.withOpacity(0.5)) : null,
              ),
            ),
            Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: goldColor, shape: BoxShape.circle), child: const Icon(Icons.camera_alt, size: 18, color: Colors.black))),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({required TextEditingController controller, required String hintText, required IconData icon, required Color accentColor, bool obscureText = false, Widget? suffixIcon, TextInputType? keyboardType}) {
    return Container(
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(15), border: Border.all(color: accentColor.withOpacity(0.4))),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
          prefixIcon: Icon(icon, color: accentColor, size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 20),
        ),
      ),
    );
  }

  Widget _buildLoginLink(Color goldColor) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("Already have an account? ", style: TextStyle(color: Colors.white70)),
          GestureDetector(onTap: () => Navigator.pop(context), child: Text('LOGIN', style: TextStyle(color: goldColor, fontWeight: FontWeight.bold, decoration: TextDecoration.underline))),
        ],
      ),
    );
  }

  Widget _buildTrustBadge(IconData icon, String label, Color accentColor) {
    return Column(children: [Icon(icon, color: accentColor, size: 28), const SizedBox(height: 8), Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold))]);
  }

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final emergencyContact = _emergencyContactController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || emergencyContact.isEmpty) {
      _showFriendlyError('Fields Missing', 'Please fill in all fields.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signUp(email, password, name, emergencyContact: emergencyContact, profileImage: _imageFile);
      if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } catch (e) {
      _showFriendlyError('Error', ErrorService.getFriendlyMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showFriendlyError(String title, String message) {
    CustomErrorDialog.show(context: context, title: title, message: message, onPrimaryAction: () => Navigator.pop(context));
  }
}

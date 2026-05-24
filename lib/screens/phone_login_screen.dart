import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/error_service.dart';
import '../widgets/glass_widgets.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phoneController = TextEditingController(text: "+260");
  final _otpController = TextEditingController();
  final _authService = AuthService();
  
  String _verificationId = '';
  bool _isOTPSent = false;
  bool _isLoading = false;

  void _sendOTP() async {
    String phone = _phoneController.text.trim();
    
    if (phone.isEmpty || !phone.startsWith('+')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter phone number with country code (e.g. +260...)'))
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.verifyPhone(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // This happens automatically on some Android devices (Auto-fill OTP)
          try {
            await _authService.signInWithCredential(credential);
            if (mounted) Navigator.pop(context);
          } catch (e) {
            debugPrint("Auto-sign-in error: $e");
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isLoading = false);
          String message = ErrorService.getFriendlyMessage(e);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _isOTPSent = true;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP Code Sent!'), backgroundColor: Colors.green));
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      String message = ErrorService.getFriendlyMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
    }
  }

  void _verifyOTP() async {
    final code = _otpController.text.trim();
    if (code.isEmpty || code.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter the 6-digit OTP')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: code,
      );
      await _authService.signInWithCredential(credential);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login Successful!'), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      String message = ErrorService.getFriendlyMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldColor = isDark ? const Color(0xFFD4AF37) : const Color(0xFFC0A060);

    return GlassScaffold(
      appBar: AppBar(
        title: const Text('Phone Login', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: GlassContainer(
            isDark: isDark,
            accentColor: goldColor,
            borderRadius: 30,
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.phonelink_ring, size: 70, color: goldColor),
                const SizedBox(height: 25),
                if (!_isOTPSent) ...[
                  const Text(
                    'Verification Required',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'We will send a 6-digit code to verify your account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 30),
                  _buildInputField(
                    controller: _phoneController,
                    hint: 'Phone Number',
                    icon: Icons.phone,
                    isDark: isDark,
                    goldColor: goldColor,
                    type: TextInputType.phone,
                  ),
                  const SizedBox(height: 30),
                  _buildActionButton(
                    label: 'SEND CODE',
                    onPressed: _isLoading ? null : _sendOTP,
                    isLoading: _isLoading,
                    color: goldColor,
                  ),
                ] else ...[
                  Text(
                    'Enter Code',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Enter the code sent to ${_phoneController.text}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 30),
                  _buildInputField(
                    controller: _otpController,
                    hint: '6-Digit OTP',
                    icon: Icons.lock_clock,
                    isDark: isDark,
                    goldColor: goldColor,
                    type: TextInputType.number,
                  ),
                  const SizedBox(height: 30),
                  _buildActionButton(
                    label: 'VERIFY & LOGIN',
                    onPressed: _isLoading ? null : _verifyOTP,
                    isLoading: _isLoading,
                    color: goldColor,
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => setState(() => _isOTPSent = false),
                    child: Text('Change number?', style: TextStyle(color: goldColor)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    required Color goldColor,
    required TextInputType type,
  }) {
    return GlassContainer(
      padding: EdgeInsets.zero,
      borderRadius: 15,
      isDark: isDark,
      accentColor: goldColor,
      blur: 10,
      child: TextField(
        controller: controller,
        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: goldColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
        keyboardType: type,
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback? onPressed,
    required bool isLoading,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.black,
          elevation: 5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: isLoading 
          ? const CircularProgressIndicator(color: Colors.black) 
          : Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
      ),
    );
  }
}

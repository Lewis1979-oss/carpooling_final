import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../services/error_service.dart';
import '../services/payment_service.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/image_picker_sheet.dart';
import 'payment_screen.dart';

class AccountSettingsScreen extends StatefulWidget {
  final UserModel userData;
  const AccountSettingsScreen({super.key, required this.userData});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _emergencyController;
  late TextEditingController _bioController;
  late TextEditingController _carModelController;
  late TextEditingController _carPlateController;
  late TextEditingController _carColorController;

  File? _selectedProfileImage;
  File? _selectedLicenseImage;
  File? _selectedVehicleImage;
  
  bool _isLoading = false;
  late bool _verificationFeePaid;
  
  // Privacy & Security States
  late bool _hidePhoneNumber;
  late bool _biometricEnabled;
  late bool _notificationsEnabled;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userData.name);
    _emailController = TextEditingController(text: widget.userData.email);
    _phoneController = TextEditingController(text: widget.userData.phone ?? '');
    _emergencyController = TextEditingController(text: widget.userData.emergencyContact ?? '');
    _bioController = TextEditingController(text: widget.userData.bio ?? '');
    _carModelController = TextEditingController(text: widget.userData.vehicleInfo?['model'] ?? '');
    _carPlateController = TextEditingController(text: widget.userData.vehicleInfo?['plate'] ?? '');
    _carColorController = TextEditingController(text: widget.userData.vehicleInfo?['color'] ?? '');
    
    _hidePhoneNumber = widget.userData.hidePhoneNumber;
    _biometricEnabled = widget.userData.biometricEnabled;
    _notificationsEnabled = widget.userData.notificationsEnabled;
    _verificationFeePaid = widget.userData.verificationFeePaid;
  }

  void _showImageSourceAction(String type) {
    // If trying to verify documents and fee not paid, show payment dialog first
    if ((type == 'license' || type == 'vehicle') && !_verificationFeePaid) {
      _showPaymentRequirementDialog(type);
      return;
    }

    final themeService = Provider.of<ThemeService>(context, listen: false);
    ImagePickerSheet.show(
      context,
      gold: themeService.goldAccent,
      isDark: themeService.isDarkMode,
      onSourceSelected: (source) => _pickImage(type, source),
    );
  }

  void _showPaymentRequirementDialog(String type) {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDark = themeService.isDarkMode;
    final gold = themeService.goldAccent;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: GlassContainer(
          isDark: isDark,
          borderRadius: 25,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_user, color: Colors.blue, size: 50),
              const SizedBox(height: 20),
              const Text(
                "ID Verification Fee",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              const Text(
                "For verification of IDs and vehicle documents, a one-time processing fee of K50 has to be paid.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Not Now", style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _openPaymentScreen(type);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: gold),
                      child: const Text("PAY K50", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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

  void _openPaymentScreen(String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          amount: 50.0,
          onPaymentSuccess: () async {
            // Update Firestore
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid != null) {
              await FirebaseFirestore.instance.collection('users').doc(uid).update({
                'verificationFeePaid': true,
              });
              setState(() => _verificationFeePaid = true);
              // Now allow picking the image
              _showImageSourceAction(type);
            }
          },
        ),
      ),
    );
  }

  Future<void> _pickImage(String type, ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 50);
    if (pickedFile != null) {
      setState(() {
        if (type == 'profile') _selectedProfileImage = File(pickedFile.path);
        if (type == 'license') _selectedLicenseImage = File(pickedFile.path);
        if (type == 'vehicle') _selectedVehicleImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitVerification() async {
    if (_selectedLicenseImage == null && _selectedVehicleImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one document to verify.')),
      );
      return;
    }

    if (!_verificationFeePaid) {
      _showPaymentRequirementDialog('submit');
      return;
    }

    setState(() => _isLoading = true);
    final authService = AuthService();
    final user = FirebaseAuth.instance.currentUser;

    try {
      await authService.submitForVerification(
        uid: user!.uid,
        userName: _nameController.text,
        licenseImage: _selectedLicenseImage,
        vehicleImage: _selectedVehicleImage,
        feePaid: _verificationFeePaid,
      );

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            title: const Text('Verification Sent'),
            content: const Text('Your documents have been sent for verification. You will receive a notification once approved.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          ),
        );
        setState(() {
          _selectedLicenseImage = null;
          _selectedVehicleImage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        final message = ErrorService.getFriendlyMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAllSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final authService = AuthService();
    final user = FirebaseAuth.instance.currentUser;

    try {
      await authService.updateUserProfile(
        uid: user!.uid,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        emergencyContact: _emergencyController.text.trim(),
        bio: _bioController.text.trim(),
        hidePhoneNumber: _hidePhoneNumber,
        biometricEnabled: _biometricEnabled,
        notificationsEnabled: _notificationsEnabled,
        profileImage: _selectedProfileImage,
        vehicleInfo: _carModelController.text.isNotEmpty ? {
          'model': _carModelController.text.trim(),
          'plate': _carPlateController.text.trim().toUpperCase(),
          'color': _carColorController.text.trim(),
          'photoUrl': widget.userData.vehicleInfo?['photoUrl'],
        } : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final message = ErrorService.getFriendlyMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;
    final gold = themeService.goldAccent;
    final double appBarHeight = MediaQuery.of(context).padding.top + kToolbarHeight;

    return GlassScaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Account Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: (isDark ? Colors.black : Colors.white).withOpacity(0.7),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: gold, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, appBarHeight + 20, 24, 40),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Photo Picker
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: gold.withOpacity(0.1),
                          backgroundImage: _selectedProfileImage != null 
                              ? FileImage(_selectedProfileImage!) 
                              : (widget.userData.profilePic != null ? NetworkImage(widget.userData.profilePic!) : null) as ImageProvider?,
                          child: _selectedProfileImage == null && widget.userData.profilePic == null 
                              ? Icon(Icons.person, size: 50, color: gold) : null,
                        ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: GestureDetector(
                            onTap: () => _showImageSourceAction('profile'),
                            child: CircleAvatar(
                              radius: 18, backgroundColor: gold,
                              child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  _buildSectionTitle('PERSONAL INFORMATION', gold),
                  _buildInputField(_nameController, 'Full Name', Icons.person, gold, isDark),
                  _buildInputField(_emailController, 'Email Address', Icons.email, gold, isDark, enabled: false),
                  _buildInputField(_phoneController, 'Phone Number', Icons.phone, gold, isDark),
                  _buildInputField(_emergencyController, 'Emergency SOS Contact', Icons.emergency, Colors.red, isDark),
                  _buildInputField(_bioController, 'About You / Bio', Icons.info_outline, gold, isDark, maxLines: 3),

                  const SizedBox(height: 30),
                  _buildSectionTitle('ACCOUNT VERIFICATION', gold),
                  _buildVerificationCard('Driver\'s License', _selectedLicenseImage, widget.userData.idCardUrl, widget.userData.verificationStatus, () => _showImageSourceAction('license'), gold, isDark),
                  const SizedBox(height: 12),
                  _buildVerificationCard('Vehicle Photo', _selectedVehicleImage, widget.userData.vehicleInfo?['photoUrl'], widget.userData.vehicleVerificationStatus, () => _showImageSourceAction('vehicle'), gold, isDark),
                  
                  if (_selectedLicenseImage != null || _selectedVehicleImage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _submitVerification,
                          icon: const Icon(Icons.send),
                          label: const Text('SUBMIT FOR VERIFICATION'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: gold,
                            side: BorderSide(color: gold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 30),
                  _buildSectionTitle('VEHICLE DETAILS', gold),
                  _buildInputField(_carModelController, 'Car Model', Icons.directions_car, gold, isDark),
                  _buildInputField(_carPlateController, 'License Plate', Icons.pin, gold, isDark),
                  _buildInputField(_carColorController, 'Car Color', Icons.color_lens, gold, isDark),

                  const SizedBox(height: 30),
                  _buildSectionTitle('PRIVACY & SECURITY', gold),
                  _buildSwitchTile('Hide phone from non-passengers', _hidePhoneNumber, (val) => setState(() => _hidePhoneNumber = val), gold, isDark),
                  _buildSwitchTile('Biometric Login', _biometricEnabled, (val) => setState(() => _biometricEnabled = val), gold, isDark),
                  _buildSwitchTile('Push Notifications', _notificationsEnabled, (val) => setState(() => _notificationsEnabled = val), gold, isDark),

                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveAllSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gold,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 5,
                      ),
                      child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white) 
                          : const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color gold) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15, left: 4),
      child: Text(title, style: TextStyle(color: gold, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
    );
  }

  Widget _buildInputField(TextEditingController controller, String label, IconData icon, Color accent, bool isDark, {bool enabled = true, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        borderRadius: 15,
        isDark: isDark,
        accentColor: accent,
        child: TextFormField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
            icon: Icon(icon, color: accent, size: 20),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationCard(String title, File? selectedFile, String? currentUrl, String status, VoidCallback onTap, Color gold, bool isDark) {
    Color statusColor = status == 'verified' ? Colors.green : (status == 'pending' ? Colors.orange : Colors.grey);
    
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        padding: const EdgeInsets.all(12),
        borderRadius: 15,
        isDark: isDark,
        accentColor: gold,
        child: Row(
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: gold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                image: (selectedFile != null || currentUrl != null) ? DecorationImage(
                  image: selectedFile != null ? FileImage(selectedFile) : NetworkImage(currentUrl!) as ImageProvider,
                  fit: BoxFit.cover,
                ) : null,
              ),
              child: (selectedFile == null && currentUrl == null) ? Icon(Icons.add_a_photo, color: gold) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.camera_alt_outlined, color: gold, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged, Color gold, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        borderRadius: 15,
        isDark: isDark,
        accentColor: gold,
        child: SwitchListTile(
          title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          value: value,
          onChanged: onChanged,
          activeColor: gold,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

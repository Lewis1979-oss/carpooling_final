import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../services/admin_service.dart';
import '../widgets/glass_widgets.dart';

class UserProfileViewScreen extends StatefulWidget {
  final String userId;
  const UserProfileViewScreen({super.key, required this.userId});

  @override
  State<UserProfileViewScreen> createState() => _UserProfileViewScreenState();
}

class _UserProfileViewScreenState extends State<UserProfileViewScreen> {
  late Future<UserModel?> _userFuture;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    _userFuture = authService.getUserData(widget.userId);
    
    if (_currentUserId != null) {
      final currentUserData = await authService.getUserData(_currentUserId!);
      if (mounted) {
        setState(() {
          _isAdmin = currentUserData?.role == 'admin';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final bool isDark = themeService.isDarkMode;
    final Color goldColor = themeService.goldAccent;

    return GlassScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: goldColor, size: 20),
          onPressed: () => Navigator.canPop(context) ? Navigator.pop(context) : Navigator.pushReplacementNamed(context, '/'),
        ),
      ),
      body: FutureBuilder<UserModel?>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final userData = snapshot.data;
          if (userData == null) {
            return const Center(child: Text('User not found.'));
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 110), // Matched padding
                _buildHeader(userData, isDark, goldColor),
                const SizedBox(height: 25),
                _buildStats(userData, goldColor, isDark),
                const SizedBox(height: 30),
                _buildBadges(userData, goldColor),
                _buildVehicleInfo(userData, goldColor, isDark),
                _buildGeneralInfo(userData, goldColor, isDark),
                
                if (_isAdmin) _buildAdminActions(userData, goldColor, isDark),
                
                const SizedBox(height: 50),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(UserModel userData, bool isDark, Color goldColor) {
    return Column(
      children: [
        Hero(
          tag: 'profile_pic_${userData.id}',
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: goldColor.withOpacity(0.5), width: 3),
            ),
            child: CircleAvatar(
              radius: 65,
              backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
              backgroundImage: userData.profilePic != null ? NetworkImage(userData.profilePic!) : null,
              child: userData.profilePic == null ? Icon(Icons.person, size: 60, color: goldColor) : null,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(userData.name, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (userData.isVerified)
              const Icon(Icons.verified, color: Colors.blue, size: 20),
            const SizedBox(width: 4),
            Text(userData.verificationStatus.toUpperCase(), style: TextStyle(color: goldColor, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
        if (userData.bio != null && userData.bio!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              userData.bio!,
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 14, fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }

  Widget _buildStats(UserModel userData, Color goldColor, bool isDark) {
    return Row(
      children: [
        Expanded(child: _buildStatCard('ZedPoints', '${userData.zedPoints}', 'Rewards', goldColor, isDark)),
        const SizedBox(width: 15),
        Expanded(child: _buildStatCard('Rating', '${userData.averageRating.toStringAsFixed(1)}', '${userData.ratingCount} Reviews', goldColor, isDark)),
      ],
    );
  }

  Widget _buildBadges(UserModel userData, Color goldColor) {
    if (userData.badges.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text('BADGES', style: TextStyle(color: goldColor, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: userData.badges.map((badge) => Chip(
            label: Text(badge, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            backgroundColor: goldColor.withOpacity(0.1),
            side: BorderSide(color: goldColor.withOpacity(0.3)),
          )).toList(),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildVehicleInfo(UserModel userData, Color goldColor, bool isDark) {
    if (userData.vehicleInfo == null) return const SizedBox.shrink();
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text('VEHICLE INFORMATION', style: TextStyle(color: goldColor, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
        ),
        const SizedBox(height: 10),
        GlassContainer(
          isDark: isDark,
          accentColor: goldColor,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.directions_car, color: goldColor, size: 30),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${userData.vehicleInfo!['color']} ${userData.vehicleInfo!['model']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Plate: ${userData.vehicleInfo!['plate']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              if (userData.vehicleInfo!['photoUrl'] != null) ...[
                const SizedBox(height: 15),
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.network(userData.vehicleInfo!['photoUrl'], height: 150, width: double.infinity, fit: BoxFit.cover),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildGeneralInfo(UserModel userData, Color goldColor, bool isDark) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text('PERSONAL DETAILS', style: TextStyle(color: goldColor, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
        ),
        const SizedBox(height: 10),
        _buildInfoTile(Icons.email, 'Email Address', userData.email, goldColor, isDark),
        _buildInfoTile(Icons.phone, 'Phone Number', userData.phone ?? "N/A", goldColor, isDark),
        _buildInfoTile(Icons.emergency, 'Emergency Contact', userData.emergencyContact ?? "N/A", goldColor, isDark),
        _buildInfoTile(Icons.history, 'Total Distance', '${userData.totalDistanceTravelled.toStringAsFixed(1)} KM', goldColor, isDark),
        _buildInfoTile(Icons.person_pin_circle, 'Account Type', userData.role.toUpperCase(), goldColor, isDark),
      ],
    );
  }

  Widget _buildAdminActions(UserModel userData, Color gold, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 40, color: Colors.white24),
        Text('ADMIN ACTIONS', style: TextStyle(color: gold, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.5)),
        const SizedBox(height: 20),
        
        // Identity Verification
        const Text('Identity Verification', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (userData.idCardUrl != null) 
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.network(userData.idCardUrl!, height: 200, width: double.infinity, fit: BoxFit.cover),
          )
        else
          Container(
            height: 100, 
            width: double.infinity, 
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(15)),
            child: const Center(child: Text('No ID Card uploaded')),
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _updateIDStatus(userData.id, 'verified'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('APPROVE ID', style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _updateIDStatus(userData.id, 'rejected'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('REJECT ID', style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 30),
        
        // Vehicle Verification
        const Text('Vehicle Verification', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _updateVehicleStatus(userData.id, 'verified'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: const Text('APPROVE VEHICLE', style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _updateVehicleStatus(userData.id, 'rejected'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('REJECT VEHICLE', style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _updateIDStatus(String uid, String status) async {
    await AdminService().updateVerificationStatus(uid, status);
    setState(() { _userFuture = Provider.of<AuthService>(context, listen: false).getUserData(widget.userId); });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Identity status updated to $status')));
  }

  void _updateVehicleStatus(String uid, String status) async {
    await AdminService().updateVehicleVerificationStatus(uid, status);
    setState(() { _userFuture = Provider.of<AuthService>(context, listen: false).getUserData(widget.userId); });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vehicle status updated to $status')));
  }

  Widget _buildStatCard(String label, String value, String subValue, Color gold, bool isDark) {
    return GlassContainer(
      isDark: isDark, accentColor: gold, padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(children: [
        Text(label, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: gold, fontSize: 24, fontWeight: FontWeight.w900)),
        Text(subValue, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ]),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String value, Color gold, bool isDark) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: gold.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: gold, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
      subtitle: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }
}

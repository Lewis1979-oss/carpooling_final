import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/admin_service.dart';
import '../services/safety_service.dart';
import '../services/theme_service.dart';
import '../services/auth_service.dart';
import '../services/rating_service.dart';
import '../models/ride_model.dart';
import '../models/user_model.dart';
import '../models/safety_report_model.dart';
import '../models/rating_model.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/admin_map_widget.dart';
import '../widgets/admin_user_action_dialog.dart';
import 'user_profile_view_screen.dart';
import 'admin_chat_list_screen.dart';
import 'ride_details_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _activeTab = 'Drivers';
  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged(String tab, int index) {
    setState(() {
      _activeTab = tab;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutQuint,
    );
  }

  Future<bool?> _showLogoutConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: GlassContainer(
          isDark: true,
          borderRadius: 20,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.logout, color: Colors.red, size: 40),
                const SizedBox(height: 20),
                const Text('Logout Admin', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 15),
                const Text(
                  'Do you want to log out of the Admin Panel and return to the login screen?', 
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false), 
                      child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('YES, LOGOUT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleBackNavigation() async {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      final bool? logout = await _showLogoutConfirmation(context);
      if (logout == true) {
        await AuthService().signOut();
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;
    final Color goldColor = themeService.goldAccent;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBackNavigation();
      },
      child: GlassScaffold(
        body: Column(
          children: [
            _buildPremiumHeader(goldColor, isDark, themeService),
            _buildNavigationTabs(goldColor, isDark, themeService),
            
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) {
                  final tabs = ['Drivers', 'Passengers', 'Trips', 'Map', 'Safety', 'Support', 'Analytics'];
                  setState(() => _activeTab = tabs[index]);
                },
                children: [
                  _buildUserTable('driver', goldColor, isDark, themeService),
                  _buildUserTable('user', goldColor, isDark, themeService),
                  _buildRideTable(goldColor, isDark, themeService),
                  const AdminMapWidget(),
                  _buildSafetyTable(goldColor, isDark, themeService),
                  _buildSupportTab(goldColor, isDark, themeService),
                  _buildAnalyticsTab(goldColor, isDark, themeService),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumHeader(Color gold, bool isDark, ThemeService theme) {
    final subtleColor = isDark ? Colors.white60 : Colors.black54;
    
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 20,
        left: 20,
        right: 20,
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black, size: 20),
                onPressed: _handleBackNavigation,
              ),
              const SizedBox(width: 4),
              Text(
                'ADMIN PANEL',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: gold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('HH:mm').format(_now),
                    style: TextStyle(
                      color: subtleColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    DateFormat('EEEE, MMM d').format(_now),
                    style: TextStyle(
                      color: subtleColor.withOpacity(0.6),
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const CircleAvatar(radius: 18, backgroundColor: Colors.transparent, child: Icon(Icons.admin_panel_settings, color: Colors.blue)),
            ],
          ),
          const SizedBox(height: 20),
          GlassContainer(
            isDark: isDark,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 0),
            borderRadius: 15,
            containerOpacity: 0.1,
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: 'Search for records...',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: gold, size: 20),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTabs(Color gold, bool isDark, ThemeService theme) {
    final tabs = [
      {'label': 'Drivers', 'icon': Icons.directions_car, 'index': 0},
      {'label': 'Passengers', 'icon': Icons.person, 'index': 1},
      {'label': 'Trips', 'icon': Icons.route, 'index': 2},
      {'label': 'Map', 'icon': Icons.map, 'index': 3},
      {'label': 'Safety', 'icon': Icons.warning, 'index': 4},
      {'label': 'Support', 'icon': Icons.chat_bubble, 'index': 5},
      {'label': 'Analytics', 'icon': Icons.analytics, 'index': 6},
    ];

    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: tabs.length,
        itemBuilder: (context, i) {
          final tab = tabs[i];
          final isActive = _activeTab == tab['label'];
          return GestureDetector(
            onTap: () => _onTabChanged(tab['label'] as String, tab['index'] as int),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isActive ? gold : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isActive ? gold : Colors.grey.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(tab['icon'] as IconData, size: 16, color: isActive ? Colors.black : Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    tab['label'] as String,
                    style: TextStyle(
                      color: isActive ? Colors.black : Colors.grey,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserTable(String role, Color gold, bool isDark, ThemeService theme) {
    return StreamBuilder<List<UserModel>>(
      stream: AdminService().getAllUsers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final users = snapshot.data!.where((u) {
          final matches = u.name.toLowerCase().contains(_searchQuery);
          return role == 'driver' ? (matches && (u.role == 'driver' || u.vehicleInfo != null)) : (matches && u.role == 'user' && u.vehicleInfo == null);
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          physics: const BouncingScrollPhysics(),
          itemCount: users.length,
          itemBuilder: (context, index) => _buildPremiumUserCard(users[index], gold, isDark, theme),
        );
      },
    );
  }

  Widget _buildPremiumUserCard(UserModel user, Color gold, bool isDark, ThemeService theme) {
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 12),
      isDark: isDark,
      padding: EdgeInsets.zero,
      borderRadius: 20,
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        leading: GestureDetector(
          onTap: () => AdminUserActionDialog.show(context, user, gold, isDark),
          child: Stack(
            children: [
              CircleAvatar(
                backgroundColor: gold.withOpacity(0.1),
                backgroundImage: user.profilePic != null ? NetworkImage(user.profilePic!) : null,
                child: user.profilePic == null ? Icon(Icons.person, color: gold) : null,
              ),
              if (user.isBlocked)
                const Positioned(
                  right: 0, bottom: 0,
                  child: CircleAvatar(radius: 6, backgroundColor: Colors.red, child: Icon(Icons.lock, size: 8, color: Colors.white)),
                ),
            ],
          ),
        ),
        title: Text(user.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black)),
        subtitle: Text('ID: ${user.verificationStatus.toUpperCase()} | Car: ${user.vehicleVerificationStatus.toUpperCase()}', style: TextStyle(color: gold, fontSize: 10, fontWeight: FontWeight.bold)),
        trailing: IconButton(
          icon: Icon(Icons.more_vert, color: isDark ? Colors.white54 : Colors.grey),
          onPressed: () => AdminUserActionDialog.show(context, user, gold, isDark),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(Icons.email_outlined, user.email, isDark),
                _infoRow(Icons.phone_outlined, user.phone ?? "N/A", isDark),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showVerificationDialog(user, gold, isDark),
                        style: ElevatedButton.styleFrom(backgroundColor: gold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        child: const Text('VIEW DOCUMENTS', style: TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfileViewScreen(userId: user.id))),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        child: const Text('FULL PROFILE', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showVerificationDialog(UserModel user, Color gold, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: GlassContainer(
          isDark: isDark,
          borderRadius: 25,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Verification Documents', style: TextStyle(color: gold, fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 20),
                  const Text('ID CARD / LICENSE', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: user.idCardUrl != null 
                      ? Image.network(user.idCardUrl!, height: 200, width: double.infinity, fit: BoxFit.cover)
                      : Container(height: 150, color: Colors.grey.withOpacity(0.1), child: const Center(child: Text('No ID Uploaded'))),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () { AdminService().updateVerificationStatus(user.id, 'verified'); Navigator.pop(context); },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: const Text('Approve ID', style: TextStyle(color: Colors.white, fontSize: 11)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () { AdminService().updateVerificationStatus(user.id, 'rejected'); Navigator.pop(context); },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('Reject ID', style: TextStyle(color: Colors.white, fontSize: 11)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),
                  const Text('VEHICLE PHOTO', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: (user.vehicleInfo != null && user.vehicleInfo!['photoUrl'] != null)
                      ? Image.network(user.vehicleInfo!['photoUrl'], height: 200, width: double.infinity, fit: BoxFit.cover)
                      : Container(height: 150, color: Colors.grey.withOpacity(0.1), child: const Center(child: Text('No Vehicle Photo'))),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () { AdminService().updateVehicleVerificationStatus(user.id, 'verified'); Navigator.pop(context); },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                          child: const Text('Approve Car', style: TextStyle(color: Colors.white, fontSize: 11)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () { AdminService().updateVehicleVerificationStatus(user.id, 'rejected'); Navigator.pop(context); },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                          child: const Text('Reject Car', style: TextStyle(color: Colors.white, fontSize: 11)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Center(child: Text('DISMISS', style: TextStyle(color: Colors.grey)))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildRideTable(Color gold, bool isDark, ThemeService theme) {
    return StreamBuilder<List<RideModel>>(
      stream: AdminService().getAllRides(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final rides = snapshot.data!.where((r) => 
          r.destination.toLowerCase().contains(_searchQuery) || 
          r.pickupLocation.toLowerCase().contains(_searchQuery)
        ).toList();
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          physics: const BouncingScrollPhysics(),
          itemCount: rides.length,
          itemBuilder: (context, index) {
            final ride = rides[index];
            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => RideDetailsScreen(ride: ride))),
              child: GlassContainer(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                isDark: isDark,
                borderRadius: 20,
                child: Row(
                  children: [
                    const Icon(Icons.route, color: Colors.blue),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${ride.pickupLocation} to ${ride.destination}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('Status: ${ride.status.toUpperCase()}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Text('K${ride.pricePerSeat}', style: TextStyle(color: gold, fontWeight: FontWeight.w900, fontSize: 14)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSafetyTable(Color gold, bool isDark, ThemeService theme) {
    return StreamBuilder<List<SafetyReportModel>>(
      stream: SafetyService().getSafetyReports(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final reports = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index];
            return GlassContainer(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(4),
              isDark: isDark,
              borderRadius: 15,
              accentColor: report.isSOS ? Colors.red : Colors.orange,
              child: ListTile(
                onTap: () => _showSafetyDetailDialog(report, gold, isDark),
                dense: true,
                leading: Icon(report.isSOS ? Icons.emergency : Icons.warning, color: report.isSOS ? Colors.red : Colors.orange),
                title: Text(report.isSOS ? 'URGENT SOS' : 'Safety Report', style: TextStyle(fontWeight: FontWeight.bold, color: report.isSOS ? Colors.red : Colors.orange)),
                subtitle: Text(report.reason, maxLines: 1, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
              ),
            );
          },
        );
      },
    );
  }

  void _showSafetyDetailDialog(SafetyReportModel report, Color gold, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: GlassContainer(
          isDark: isDark,
          borderRadius: 25,
          child: FutureBuilder<UserModel?>(
            future: AdminService().getAllUsers().first.then((users) => users.firstWhere((u) => u.id == report.reporterId)),
            builder: (context, userSnap) {
              final reporter = userSnap.data;
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Icon(report.isSOS ? Icons.emergency : Icons.warning, color: report.isSOS ? Colors.red : Colors.orange, size: 28),
                          const SizedBox(height: 8),
                          Text(
                            report.isSOS ? 'URGENT SOS' : 'SAFETY REPORT',
                            style: TextStyle(fontWeight: FontWeight.w900, color: report.isSOS ? Colors.red : Colors.orange, letterSpacing: 1.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundImage: reporter?.profilePic != null ? NetworkImage(reporter!.profilePic!) : null,
                            child: reporter?.profilePic == null ? Icon(Icons.person, color: gold, size: 40) : null,
                          ),
                          TextButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfileViewScreen(userId: report.reporterId))),
                            child: const Text('View Full Profile', style: TextStyle(color: Colors.blue, fontSize: 12, decoration: TextDecoration.underline)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _detailLabel('Report ID'),
                    _detailValue(report.id, isDark),
                    const SizedBox(height: 12),
                    _detailLabel('Time'),
                    _detailValue(DateFormat('MMM d, hh:mm a').format(report.timestamp), isDark),
                    const SizedBox(height: 12),
                    _detailLabel('Reason'),
                    _detailValue(report.reason, isDark),
                    const SizedBox(height: 20),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 10),
                    const Text('SENDER INFO', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                    const SizedBox(height: 15),
                    _detailLabel('Name'),
                    _detailValue(reporter?.name ?? 'Loading...', isDark),
                    const SizedBox(height: 10),
                    _detailLabel('User ID'),
                    _detailValue(report.reporterId, isDark),
                    const SizedBox(height: 10),
                    _detailLabel('Phone Number'),
                    _detailValue(reporter?.phone ?? 'N/A', isDark),
                    const SizedBox(height: 30),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('DISMISS', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _detailLabel(String label) {
    return Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold));
  }

  Widget _detailValue(String value, bool isDark) {
    return Text(value, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13, fontWeight: FontWeight.w500));
  }

  Widget _buildSupportTab(Color gold, bool isDark, ThemeService theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: gold.withOpacity(0.2)),
          const SizedBox(height: 20),
          Text('User Support Interface', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black)),
          const SizedBox(height: 10),
          const Text('Manage conversations and announcements.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminChatListScreen())),
            icon: const Icon(Icons.forum, color: Colors.black),
            label: const Text('OPEN CHATS', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: gold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab(Color gold, bool isDark, ThemeService theme) {
    return StreamBuilder<List<RideModel>>(
      stream: AdminService().getAllRides(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final rides = snapshot.data!;
        double revenue = 0;
        for (var r in rides) { revenue += (r.pricePerSeat * r.paidPassengers.length); }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildStatCard('TOTAL REVENUE', 'K${revenue.toStringAsFixed(2)}', Icons.payments, Colors.green, isDark, theme),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: _buildStatCard('COMPLETED', rides.where((r) => r.status == 'completed').length.toString(), Icons.check_circle, gold, isDark, theme)),
                const SizedBox(width: 15),
                Expanded(child: _buildStatCard('ACTIVE', rides.where((r) => r.status != 'completed').length.toString(), Icons.directions_car, Colors.blue, isDark, theme)),
              ],
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () => launchUrl(Uri.parse('https://console.firebase.google.com/')),
              icon: const Icon(Icons.dashboard_customize, color: Colors.white),
              label: const Text('FIREBASE CONSOLE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), minimumSize: const Size.fromHeight(55)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String val, IconData icon, Color accent, bool isDark, ThemeService theme) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      isDark: isDark,
      borderRadius: 20,
      accentColor: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 24),
          const SizedBox(height: 15),
          Text(val, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black)),
          Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ],
      ),
    );
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../models/ride_model.dart';
import '../models/user_model.dart';
import '../services/ride_service.dart';
import '../services/auth_service.dart';
import '../services/safety_service.dart';
import '../services/chat_service.dart';
import '../services/theme_service.dart';
import '../services/notification_service.dart';
import '../services/voice_call_service.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/call_choice_dialog.dart';
import 'chat_screen.dart';
import 'live_tracking_screen.dart';
import 'user_profile_view_screen.dart';

class RideDetailsScreen extends StatefulWidget {
  final RideModel ride;
  const RideDetailsScreen({super.key, required this.ride});

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  late Stream<RideModel> _rideStream;
  final String emergencyPhoneNumber = "+260964256282";
  bool _isLoadingAction = false;

  @override
  void initState() {
    super.initState();
    _rideStream = RideService().getRideById(widget.ride.id);
  }

  void _showSOSDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    bool? confirm = await showDialog<bool>(
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
                const Text('EMERGENCY SOS', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 15),
                const Text('This will alert Admin immediately. Are you in danger?', textAlign: TextAlign.center),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('YES, SOS', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirm == true && user != null) {
      await SafetyService().reportIssue(widget.ride.id, user.uid, 'SOS SIGNAL FROM RIDE DETAILS', isSOS: true);
      final Uri tel = Uri(scheme: 'tel', path: emergencyPhoneNumber);
      if (await canLaunchUrl(tel)) await launchUrl(tel);
    }
  }

  void _shareRideDetails(RideModel ride) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final driver = await authService.getUserData(ride.driverId);

    final String shareText = '''
🛡️ *ZedPool Security Share* 🛡️
I'm sharing my trip details with you for security purposes.

📍 *Pickup:* ${ride.pickupLocation}
🏁 *Destination:* ${ride.destination}
📅 *Date:* ${DateFormat('dd MMM yyyy').format(ride.dateTime)}
⏰ *Time:* ${DateFormat('hh:mm a').format(ride.dateTime)}
🔄 *Type:* ${ride.rideType == 'one-way' ? 'One-way' : 'Round-trip'}

🚗 *Vehicle Details:*
• Model: ${ride.vehicleInfo?['model'] ?? 'Standard Vehicle'}
• Plate: ${ride.vehicleInfo?['plate'] ?? 'N/A'}
• Color: ${ride.vehicleInfo?['color'] ?? 'N/A'}

👤 *Driver Info:*
• Name: ${driver?.name ?? 'Unknown'}
• Phone: ${driver?.phone ?? 'N/A'}

*This is a security feature to keep family and friends informed.*
''';
    Share.share(shareText, subject: 'My Ride Safety Details');
  }

  void _initiateCall(UserModel user) {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => CallChoiceDialog(
        otherUser: user,
        gold: themeService.goldAccent,
        isDark: themeService.isDarkMode,
        onZedPoolCall: () async {
          final callService = Provider.of<VoiceCallService>(context, listen: false);
          await callService.makeCall(receiver: user);
        },
        onCellularCall: () async {
          if (user.phone != null) {
            final Uri tel = Uri(scheme: 'tel', path: user.phone);
            if (await canLaunchUrl(tel)) await launchUrl(tel);
          }
        },
      ),
    );
  }

  void _showSafetyChecklist(VoidCallback onProceed) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: GlassContainer(
          isDark: true,
          borderRadius: 25,
          accentColor: Colors.orange,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Icon(Icons.shield, color: Colors.orange),
                  SizedBox(width: 10),
                  Text('NIGHT SAFETY CHECK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                ],
              ),
              const SizedBox(height: 20),
              _buildCheckItem(Icons.directions_car, "Confirm number plate matches."),
              _buildCheckItem(Icons.person, "Verify driver's identity and face."),
              _buildCheckItem(Icons.lock_person, "Provide the security PIN to the driver."),
              _buildCheckItem(Icons.share_location, "Share your tracking link with family."),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onProceed();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, minimumSize: const Size(double.infinity, 50)),
                child: const Text('PROCEED SECURELY', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.white60, size: 16),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13))),
        ],
      ),
    );
  }

  void _showPinEntryDialog(RideModel ride) {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: GlassContainer(
          isDark: true,
          borderRadius: 25,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('SECURITY HANDSHAKE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
              const SizedBox(height: 15),
              const Text('Ask the passenger for their 4-digit security PIN to unlock this trip.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 25),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 10),
                decoration: const InputDecoration(
                  hintText: '----',
                  hintStyle: TextStyle(color: Colors.white24),
                  border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () async {
                  final success = await RideService().verifyRidePin(ride.id, pinController.text.trim());
                  if (success) {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => LiveTrackingScreen(rideId: ride.id, isDriver: true)));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Security PIN. Please check with passenger.')));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('VERIFY & START'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _resendPinToDriver(RideModel ride) async {
    final notificationService = NotificationService();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    setState(() => _isLoadingAction = true);
    try {
      await notificationService.sendNotificationToUser(
        targetUserId: ride.driverId,
        title: 'Security PIN Reminder',
        body: '${user.displayName ?? 'Your passenger'} has resent their Security PIN: ${ride.pinCode}',
        rideId: ride.id,
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Security PIN sent to driver via notification.'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to resend PIN. Please check connection.')));
    } finally {
      if (mounted) setState(() => _isLoadingAction = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rideService = RideService();
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = FirebaseAuth.instance.currentUser;
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;
    final activeGold = themeService.goldAccent;

    return StreamBuilder<RideModel>(
      stream: _rideStream,
      initialData: widget.ride,
      builder: (context, snapshot) {
        final ride = snapshot.data ?? widget.ride;
        final bool isDriver = currentUser?.uid == ride.driverId;
        final bool isPassenger = ride.passengers.contains(currentUser?.uid);
        final bool isPending = ride.pendingPassengers.contains(currentUser?.uid);
        final bool isWaitlisted = ride.waitlist.contains(currentUser?.uid);
        final bool isCompleted = ride.status == 'completed' || ride.status == 'cancelled';
        final bool isOngoing = ride.status == 'ongoing';

        return GlassScaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios, color: activeGold, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Ride Details',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
            actions: [
              if (isPassenger || isDriver) ...[
                PremiumSOSButton(onTap: _showSOSDialog),
                const SizedBox(width: 8),
              ],
              IconButton(
                icon: const Icon(Icons.share_outlined, color: Colors.blue, size: 24),
                tooltip: 'Share for security',
                onPressed: () => _shareRideDetails(ride),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 100),
                
                // Verified/LadyPool Badges
                if (ride.verifiedOnly || ride.ladiesOnly || ride.isLateNight)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        if (ride.verifiedOnly)
                          _buildBadge(Icons.verified_user, 'VERIFIED ONLY', Colors.blue, isDark),
                        if (ride.ladiesOnly) ...[
                          const SizedBox(width: 10),
                          _buildBadge(Icons.female, 'LADY-POOL', Colors.pinkAccent, isDark),
                        ],
                        if (ride.isLateNight) ...[
                          const SizedBox(width: 10),
                          _buildBadge(Icons.nightlight_round, 'NIGHT SAFETY', Colors.orange, isDark),
                        ],
                      ],
                    ),
                  ),

                // Late Night PIN Display for Passenger
                if (ride.isLateNight && isPassenger && !isOngoing && !isCompleted)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: GlassContainer(
                      isDark: isDark,
                      accentColor: Colors.orange,
                      padding: const EdgeInsets.all(20),
                      borderRadius: 20,
                      child: Column(
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock_person, color: Colors.orange, size: 16),
                              SizedBox(width: 8),
                              Text('YOUR SECURITY PIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(ride.pinCode ?? '----', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 8)),
                          const SizedBox(height: 15),
                          const Text('Give this PIN to the driver when you enter the vehicle.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _isLoadingAction ? null : () => _resendPinToDriver(ride),
                            icon: const Icon(Icons.send_rounded, size: 16),
                            label: const Text('RESEND PIN TO DRIVER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.withOpacity(0.2),
                              foregroundColor: Colors.orange,
                              side: const BorderSide(color: Colors.orange),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Driver Profile Header
                FutureBuilder<UserModel?>(
                  future: authService.getUserData(ride.driverId),
                  builder: (context, snapshot) {
                    final driver = snapshot.data;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GlassContainer(
                            isDark: isDark,
                            padding: const EdgeInsets.all(20),
                            borderRadius: 25,
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfileViewScreen(userId: ride.driverId))),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: activeGold.withOpacity(0.5), width: 2),
                                    ),
                                    child: CircleAvatar(
                                      radius: 30,
                                      backgroundImage: driver?.profilePic != null ? NetworkImage(driver!.profilePic!) : null,
                                      child: driver?.profilePic == null ? Icon(Icons.person, size: 30, color: activeGold) : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              driver?.name ?? 'Loading...',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (driver?.isVerified ?? false)
                                            const Padding(
                                              padding: EdgeInsets.only(left: 6),
                                              child: Icon(Icons.verified, color: Colors.blue, size: 16),
                                            ),
                                          if (driver?.badges.contains('Gold Member') ?? false)
                                            const Padding(
                                              padding: EdgeInsets.only(left: 6),
                                              child: Icon(Icons.stars, color: Colors.amber, size: 16),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.star, color: Colors.amber, size: 14),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${driver?.averageRating.toStringAsFixed(1) ?? "5.0"} (Driver)',
                                            style: TextStyle(color: isDark ? Colors.white60 : Colors.grey, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                _buildCircularButton(Icons.phone_outlined, activeGold, () async {
                                  if (driver != null) {
                                    _initiateCall(driver);
                                  }
                                }, isDark),
                                const SizedBox(width: 10),
                                _buildCircularButton(Icons.chat_bubble_outline, activeGold, () {
                                  if (currentUser != null) {
                                    final chatService = ChatService();
                                    final chatId = chatService.getPrivateChatId(currentUser.uid, ride.driverId);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ChatScreen(
                                          rideId: ride.id,
                                          destinationName: ride.destination,
                                          privateChatId: chatId,
                                          otherUserName: driver?.name ?? 'Driver',
                                        ),
                                      ),
                                    );
                                  }
                                }, isDark),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                          _buildSectionHeader('VEHICLE DETAILS', activeGold),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: GlassContainer(
                              isDark: isDark,
                              padding: const EdgeInsets.all(20),
                              borderRadius: 25,
                              blur: 0,
                              containerOpacity: isDark ? 0.05 : 0.3,
                              child: Row(
                                children: [
                                  Container(
                                    width: 110, // Increased from 80
                                    height: 80, // Increased from 60
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(15),
                                      image: DecorationImage(
                                        image: (ride.vehicleInfo?['photoUrl'] != null)
                                            ? NetworkImage(ride.vehicleInfo!['photoUrl'])
                                            : const NetworkImage('https://images.toyota-europe.com/eu/avensis/6f6f9c9a-7c9b-4b1a-8b1a-9b1a9b1a9b1a/width/400/exterior-1.png'),
                                        fit: BoxFit.cover, // Changed to cover focus better
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center, // Centered vertically
                                      crossAxisAlignment: CrossAxisAlignment.center, // Centered horizontally
                                      children: [
                                        Text(
                                          ride.vehicleInfo?['model'] ?? 'Standard Vehicle', 
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${ride.vehicleInfo?['plate'] ?? "N/A"} • ${ride.vehicleInfo?['color'] ?? "N/A"}', 
                                          style: TextStyle(color: isDark ? Colors.white60 : Colors.grey, fontSize: 12),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (driver?.vehicleVerificationStatus == 'verified')
                                    const Icon(Icons.verified, color: Colors.blue, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Main Route Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GlassContainer(
                    isDark: isDark,
                    padding: const EdgeInsets.all(24),
                    borderRadius: 25,
                    child: Column(
                      children: [
                        _buildRouteRow(
                          ride.pickupLocation,
                          'Pickup Location', 
                          DateFormat('hh:mm a').format(ride.dateTime),
                          activeGold,
                          isDark,
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.only(left: 9),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Column(
                              children: List.generate(3, (index) => Container(
                                margin: const EdgeInsets.symmetric(vertical: 2),
                                width: 1,
                                height: 8,
                                color: activeGold.withOpacity(0.3),
                              )),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildRouteRow(
                          ride.destination,
                          'Drop-off Point',
                          DateFormat('hh:mm a').format(ride.dateTime.add(Duration(minutes: ride.estimatedDuration ?? 150))),
                          Colors.orange,
                          isDark,
                        ),
                        const Divider(height: 40, color: Colors.white10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildInfoColumn(Icons.calendar_today_outlined, DateFormat('dd MMM').format(ride.dateTime), 'Date', activeGold, isDark),
                            _buildInfoColumn(Icons.straighten, '${ride.estimatedDistance?.toStringAsFixed(1) ?? "0.0"} km', 'Distance', activeGold, isDark),
                            _buildInfoColumn(Icons.event_seat_outlined, '${ride.availableSeats}', 'Seats', activeGold, isDark),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Price Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GlassContainer(
                    isDark: isDark,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    borderRadius: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Price per seat',
                              style: TextStyle(color: isDark ? Colors.white60 : Colors.grey, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'K${ride.pricePerSeat}',
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: activeGold),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: activeGold.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: activeGold.withOpacity(0.3)),
                          ),
                          child: Text(
                            'Pay on board',
                            style: TextStyle(color: activeGold, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Passengers List
                if (ride.passengers.isNotEmpty || ride.pendingPassengers.isNotEmpty) ...[
                  _buildSectionHeader('PASSENGERS', activeGold),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: ride.passengers.length + ride.pendingPassengers.length,
                    itemBuilder: (context, index) {
                      bool isConfirmed = index < ride.passengers.length;
                      String pUid = isConfirmed ? ride.passengers[index] : ride.pendingPassengers[index - ride.passengers.length];
                      
                      return FutureBuilder<UserModel?>(
                        future: authService.getUserData(pUid),
                        builder: (context, pSnap) {
                          final pUser = pSnap.data;
                          return ListTile(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfileViewScreen(userId: pUid))),
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundImage: pUser?.profilePic != null ? NetworkImage(pUser!.profilePic!) : null,
                              child: pUser?.profilePic == null ? const Icon(Icons.person) : null,
                            ),
                            title: Row(
                              children: [
                                Expanded(child: Text(pUser?.name ?? 'Loading...', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                                if (isConfirmed && isDriver) 
                                  IconButton(
                                    icon: Icon(Icons.phone_outlined, color: activeGold, size: 20),
                                    onPressed: () {
                                      if (pUser != null) _initiateCall(pUser);
                                    },
                                  ),
                              ],
                            ),
                            subtitle: Text(isConfirmed ? 'Confirmed Passenger' : 'Pending Approval', style: TextStyle(color: isConfirmed ? Colors.green : Colors.orange, fontSize: 10)),
                            trailing: isDriver && !isConfirmed ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: () => rideService.approvePassenger(ride.id, pUid)),
                                IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => rideService.rejectPassenger(ride.id, pUid)),
                              ],
                            ) : (isConfirmed && isDriver ? IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => _confirmCancelParticipation(pUid)) : null),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                ],

                // Preferences
                _buildSectionHeader('PREFERENCES', activeGold),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GlassContainer(
                    isDark: isDark,
                    padding: const EdgeInsets.all(20),
                    borderRadius: 25,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildPreferenceIcon(Icons.ac_unit, 'A/C', ride.preferences['ac'] == true, activeGold, isDark),
                        _buildPreferenceIcon(Icons.smoking_rooms, 'Smoking', ride.preferences['smoking'] == true, activeGold, isDark),
                        _buildPreferenceIcon(Icons.music_note, 'Music', ride.preferences['music'] == true, activeGold, isDark),
                        _buildPreferenceIcon(Icons.volume_off, 'Quiet', ride.preferences['quiet'] == true, activeGold, isDark),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Driver notes
                if (ride.notes != null && ride.notes!.isNotEmpty) ...[
                  _buildSectionHeader('DRIVER NOTES', activeGold),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: GlassContainer(
                      isDark: isDark,
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      borderRadius: 20,
                      child: Text(
                        '“ ${ride.notes} ”',
                        style: TextStyle(fontStyle: FontStyle.italic, color: isDark ? Colors.white70 : Colors.black54, fontSize: 14),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 140),
              ],
            ),
          ),
          bottomSheet: GlassContainer(
            isDark: isDark,
            padding: const EdgeInsets.all(20),
            borderRadius: 0,
            blur: 40,
            borderWidth: 0,
            containerOpacity: 0.1,
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: _isLoadingAction 
                ? const Center(child: CircularProgressIndicator())
                : isCompleted 
                  ? Center(child: Text('TRIP COMPLETED', style: TextStyle(fontWeight: FontWeight.w900, color: activeGold, letterSpacing: 2)))
                  : isDriver
                    ? Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                if (ride.isLateNight && !isOngoing) {
                                  _showPinEntryDialog(ride);
                                } else {
                                  if (!isOngoing) rideService.updateRideStatus(ride.id, 'ongoing');
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => LiveTrackingScreen(rideId: ride.id, isDriver: isDriver)));
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ride.isLateNight && !isOngoing ? Colors.orange : activeGold,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              ),
                              child: Text(
                                isOngoing ? 'LIVE TRACKING' : (ride.isLateNight ? 'START (PIN REQ.)' : 'START RIDE'),
                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            onPressed: _confirmCancelRide,
                            icon: const Icon(Icons.delete_forever, color: Colors.red),
                            tooltip: 'Cancel Ride',
                          ),
                        ],
                      )
                    : (isPassenger || isPending || isWaitlisted)
                      ? Row(
                          children: [
                            if (isPassenger)
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (ride.isLateNight) {
                                      _showSafetyChecklist(() {
                                         Navigator.push(context, MaterialPageRoute(builder: (context) => LiveTrackingScreen(rideId: ride.id, isDriver: false)));
                                      });
                                    } else {
                                       Navigator.push(context, MaterialPageRoute(builder: (context) => LiveTrackingScreen(rideId: ride.id, isDriver: false)));
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: activeGold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                                  child: const Text('TRACK RIDE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            if (isPending || isWaitlisted)
                              Expanded(child: Center(child: Text(isPending ? 'WAITING FOR APPROVAL' : 'ON WAITLIST', style: TextStyle(color: activeGold, fontWeight: FontWeight.bold)))),
                            const SizedBox(width: 10),
                            OutlinedButton(
                              onPressed: () => _confirmCancelParticipation(currentUser!.uid),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                              child: const Text('CANCEL'),
                            ),
                          ],
                        )
                      : ride.availableSeats > 0
                        ? ElevatedButton(
                            onPressed: () => _handleJoinRequest(currentUser?.uid, ride),
                            style: ElevatedButton.styleFrom(backgroundColor: activeGold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                            child: const Text('REQUEST TO JOIN', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          )
                        : ElevatedButton(
                            onPressed: () => _handleWaitlist(currentUser?.uid, ride),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                            child: const Text('JOIN WAITLIST', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBadge(IconData icon, String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
        ],
      ),
    );
  }

  Future<void> _handleJoinRequest(String? uid, RideModel ride) async {
    if (uid == null) return;
    setState(() => _isLoadingAction = true);
    try {
      await RideService().requestToJoin(ride.id, uid);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent to driver')));
    } finally {
      if (mounted) setState(() => _isLoadingAction = false);
    }
  }

  Future<void> _handleWaitlist(String? uid, RideModel ride) async {
    if (uid == null) return;
    setState(() => _isLoadingAction = true);
    try {
      await RideService().joinWaitlist(ride.id, uid);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to waitlist! We will notify you if a seat opens.')));
    } finally {
      if (mounted) setState(() => _isLoadingAction = false);
    }
  }

  void _confirmCancelParticipation(String uid) async {
    bool? confirm = await _showConfirmDialog('Cancel Request?', 'Are you sure you want to cancel your participation in this ride?');
    if (confirm == true) {
      setState(() => _isLoadingAction = true);
      await RideService().cancelParticipation(widget.ride.id, uid);
      if (mounted) setState(() => _isLoadingAction = false);
    }
  }

  void _confirmCancelRide() async {
    bool? confirm = await _showConfirmDialog('Cancel Entire Ride?', 'This will notify all passengers and delete the ride. Action cannot be undone.');
    if (confirm == true) {
      setState(() => _isLoadingAction = true);
      await RideService().updateRideStatus(widget.ride.id, 'cancelled');
      if (mounted) {
        setState(() => _isLoadingAction = false);
        Navigator.pop(context);
      }
    }
  }

  Future<bool?> _showConfirmDialog(String title, String body) {
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
                const SizedBox(height: 10),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 15),
                Text(body, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No', style: TextStyle(color: Colors.grey))),
                    ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Yes, Proceed')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color gold) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Text(
        title,
        style: TextStyle(color: gold, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildRouteRow(String location, String label, String time, Color accent, bool isDark) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: accent, width: 2),
          ),
          child: Center(child: Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: accent))),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(location, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(label, style: TextStyle(color: isDark ? Colors.white38 : Colors.grey, fontSize: 11)),
            ],
          ),
        ),
        Text(time, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
      ],
    );
  }

  Widget _buildInfoColumn(IconData icon, String value, String label, Color gold, bool isDark) {
    return Column(
      children: [
        Icon(icon, color: gold.withOpacity(0.5), size: 20),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: TextStyle(color: isDark ? Colors.white38 : Colors.grey, fontSize: 10)),
      ],
    );
  }

  Widget _buildPreferenceIcon(IconData icon, String label, bool isActive, Color gold, bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isActive ? gold.withOpacity(0.1) : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: isActive ? gold : Colors.white10),
          ),
          child: Icon(icon, color: isActive ? gold : Colors.grey, size: 20),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(color: isActive ? gold : Colors.grey, fontSize: 9, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  Widget _buildCircularButton(IconData icon, Color color, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

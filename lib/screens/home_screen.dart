import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../models/ride_model.dart';
import '../models/user_model.dart';
import '../services/ride_service.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../widgets/glass_widgets.dart';
import 'post_ride_screen.dart';
import 'ride_details_screen.dart';
import 'search_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatelessWidget {
  final GlobalKey? recentRoutesKey;
  final GlobalKey? bookRideKey;
  final GlobalKey? postRideKey;
  final GlobalKey? fabKey;

  const HomeScreen({
    super.key, 
    this.recentRoutesKey, 
    this.bookRideKey, 
    this.postRideKey, 
    this.fabKey
  });

  @override
  Widget build(BuildContext context) {
    final rideService = RideService();
    final authService = Provider.of<AuthService>(context, listen: false);
    final themeService = Provider.of<ThemeService>(context);
    final user = FirebaseAuth.instance.currentUser;
    final bool isDark = themeService.isDarkMode;
    final isTealTheme = themeService.appTheme == AppTheme.tealGold;

    final Color goldColor = themeService.goldAccent;

    return GlassScaffold(
      body: FutureBuilder<UserModel?>(
        future: authService.getUserData(user?.uid ?? ''),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return _buildHomeScreenShimmer(isDark, goldColor);
          }
          
          final userData = userSnapshot.data;
          if (userData == null) return const Center(child: Text("Please log in to continue"));

          final fullName = userData.name;
          final firstName = fullName.split(' ').first;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 108),

                // 2. Header: Greeting, Name!
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${themeService.greeting},',
                            style: TextStyle(
                              fontSize: 16 * themeService.fontSizeFactor,
                              color: isDark ? Colors.white70 : Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                firstName,
                                style: TextStyle(
                                  fontSize: 28 * themeService.fontSizeFactor,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontFamily: themeService.fontFamily,
                                ),
                              ),
                              if (userData.isVerified)
                                const Padding(
                                  padding: EdgeInsets.only(left: 6, top: 4),
                                  child: Icon(Icons.verified, color: Colors.blue, size: 24),
                                ),
                              if (userData.badges.contains('Gold Member'))
                                const Padding(
                                  padding: EdgeInsets.only(left: 6, top: 4),
                                  child: Icon(Icons.stars, color: Colors.amber, size: 24),
                                ),
                            ],
                          ),
                        ],
                      ),
                      // User Profile Photo Icon
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: goldColor.withOpacity(0.5), width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                            backgroundImage: userData.profilePic != null ? NetworkImage(userData.profilePic!) : null,
                            child: userData.profilePic == null 
                                ? Icon(Icons.person, color: goldColor, size: 28) 
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // 3. Action Box (Compact Layout with Fixed Measurements)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GlassContainer(
                    isDark: isDark,
                    padding: const EdgeInsets.only(top: 2, bottom: 2, left: 10, right: 10),
                    borderRadius: 30,
                    containerOpacity: isDark ? 0.05 : 0.4,
                    blur: 0, 
                    child: Column(
                      children: [
                        Text(
                          "WHAT'S YOUR TRAVEL PLAN TODAY?",
                          style: TextStyle(
                            color: goldColor, 
                            fontSize: 18 * themeService.fontSizeFactor, 
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            shadows: [
                              Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 1))
                            ]
                          ),
                        ),
                        const SizedBox(height: 1),
                        // Car Image Widget
                        Image.asset(
                          'assets/images/vehicle_bg.png',
                          height: 125,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 1),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildActionTile(
                              key: bookRideKey,
                              icon: Icons.map,
                              label: 'Book Ride',
                              subLabel: 'Find on map',
                              accentColor: goldColor,
                              isDark: isDark,
                              isTeal: isTealTheme,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchScreen())),
                            ),
                            const SizedBox(width: 15),
                            _buildActionTile(
                              key: postRideKey,
                              icon: Icons.add_location_alt,
                              label: 'Post Ride',
                              subLabel: 'Share route',
                              accentColor: goldColor,
                              isDark: isDark,
                              isTeal: isTealTheme,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PostRideScreen())),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 35),

                // Upcoming Rides Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recommended for You',
                        style: TextStyle(
                          fontSize: 18 * themeService.fontSizeFactor,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchScreen())),
                        child: Row(
                          children: [
                            Text(
                              'See all',
                              style: TextStyle(color: goldColor, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios, size: 10, color: goldColor),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 15),

                StreamBuilder<List<RideModel>>(
                  stream: rideService.getRides(userData),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildRecentRoutesShimmer(isDark, goldColor);
                    }
                    
                    final rides = snapshot.data ?? [];
                    if (rides.isEmpty) {
                      return _buildEmptyState(context, goldColor, isDark, themeService.fontSizeFactor);
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: rides.length > 3 ? 3 : rides.length,
                      itemBuilder: (context, index) {
                        final ride = rides[index];
                        return FutureBuilder<UserModel?>(
                          future: authService.getUserData(ride.driverId),
                          builder: (context, driverSnap) {
                            final driver = driverSnap.data;
                            return _buildListRideCard(context, ride, driver, isDark, goldColor, isTealTheme);
                          },
                        );
                      },
                    );
                  },
                ),
                
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        key: fabKey,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PostRideScreen()),
        ),
        backgroundColor: goldColor,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, color: Colors.black, size: 30),
      ),
    );
  }

  Widget _buildActionTile({
    Key? key,
    required IconData icon, 
    required String label, 
    required String subLabel,
    required Color accentColor, 
    required bool isDark,
    required bool isTeal,
    required VoidCallback onTap
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        width: 130,
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: accentColor.withOpacity(0.2), width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: accentColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label, 
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 12, 
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subLabel, 
                    style: TextStyle(
                      fontSize: 9, 
                      color: isDark ? Colors.white60 : Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListRideCard(BuildContext context, RideModel ride, UserModel? driver, bool isDark, Color goldColor, bool isTeal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassContainer(
        isDark: isDark,
        padding: const EdgeInsets.all(16),
        borderRadius: 20,
        blur: 15,
        containerOpacity: 0.05,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => RideDetailsScreen(ride: ride)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (ride.verifiedOnly)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(Icons.verified, color: Colors.blue, size: 14),
                              ),
                            if (ride.ladiesOnly)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(Icons.female, color: Colors.pinkAccent, size: 14),
                              ),
                            Expanded(
                              child: Text(
                                '${ride.pickupLocation.split(',').first} to ${ride.destination.split(',').first}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 14, color: goldColor),
                            const SizedBox(width: 6),
                            Text(
                              DateFormat('hh:mm a').format(ride.dateTime),
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.grey),
                            ),
                            const SizedBox(width: 15),
                            if (ride.availableSeats == 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                                child: const Text('FULL - WAITLIST', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: goldColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: goldColor.withOpacity(0.5)),
                    ),
                    child: Text(
                      'K${ride.pricePerSeat}',
                      style: TextStyle(color: goldColor, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: goldColor.withOpacity(0.1),
                    backgroundImage: driver?.profilePic != null ? NetworkImage(driver!.profilePic!) : null,
                    child: driver?.profilePic == null ? Icon(Icons.person, size: 16, color: goldColor) : null,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver?.name ?? 'Loading...',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 12),
                          const SizedBox(width: 2),
                          Text(
                            driver?.averageRating.toStringAsFixed(1) ?? '5.0',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios, size: 14, color: goldColor.withOpacity(0.7)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, Color gold, bool isDark, double fontSizeFactor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Icon(Icons.directions_car_filled_outlined, size: 80, color: gold.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'No recommended rides yet.',
            style: TextStyle(fontSize: 16 * fontSizeFactor, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
          ),
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SearchScreen()),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: gold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Search for Rides', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeScreenShimmer(bool isDark, Color gold) {
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: Column(
        children: [
          const SizedBox(height: 108),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(width: 150, height: 30, color: Colors.white),
                const CircleAvatar(radius: 22),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(width: double.infinity, height: 200, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30))),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentRoutesShimmer(bool isDark, Color gold) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      shrinkWrap: true,
      itemCount: 3,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
        child: Container(
          height: 100,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }
}

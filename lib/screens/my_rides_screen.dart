import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/ride_model.dart';
import '../models/user_model.dart';
import '../services/ride_service.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../widgets/glass_widgets.dart';
import 'live_tracking_screen.dart';
import 'rating_dialog.dart';
import 'ride_details_screen.dart';

class MyRidesScreen extends StatelessWidget {
  const MyRidesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rideService = RideService();
    final authService = AuthService();
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;
    final activeGold = themeService.goldAccent;

    Stream<List<RideModel>> getAllMyRides() {
      return FirebaseFirestore.instance.collection('rides').snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) => RideModel.fromMap(doc.data(), doc.id))
            .where((ride) {
          final isInvolved = ride.driverId == userId || 
                           ride.passengers.contains(userId) ||
                           ride.pendingPassengers.contains(userId) ||
                           ride.waitlist.contains(userId);
          final isDeleted = ride.deletedBy.contains(userId);
          return isInvolved && !isDeleted;
        }).toList();
      });
    }

    return DefaultTabController(
      length: 3,
      child: GlassScaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 80,
          automaticallyImplyLeading: false,
          title: Padding(
            padding: const EdgeInsets.only(top: 20, left: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'My Rides',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                Text(
                  'Manage your upcoming and past rides',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          centerTitle: false,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: GlassContainer(
                padding: EdgeInsets.zero,
                borderRadius: 25,
                isDark: isDark,
                containerOpacity: 0.1,
                child: TabBar(
                  indicatorWeight: 0,
                  dividerColor: Colors.transparent,
                  labelColor: activeGold,
                  unselectedLabelColor: isDark ? Colors.white38 : Colors.grey,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    color: activeGold.withOpacity(0.15),
                  ),
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  tabs: const [
                    Tab(text: 'Upcoming', height: 45),
                    Tab(text: 'Ongoing', height: 45),
                    Tab(text: 'Past', height: 45),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _buildFilteredRideList(getAllMyRides(), ['upcoming'], 'UPCOMING RIDES', userId, rideService, authService, activeGold, isDark, themeService),
            _buildFilteredRideList(getAllMyRides(), ['ongoing'], 'ACTIVE TRIPS', userId, rideService, authService, activeGold, isDark, themeService),
            _buildFilteredRideList(getAllMyRides(), ['completed', 'cancelled'], 'TRIP HISTORY', userId, rideService, authService, activeGold, isDark, themeService),
          ],
        ),
      ),
    );
  }

  Widget _buildFilteredRideList(Stream<List<RideModel>> stream, List<String> statuses, String sectionTitle, String userId, RideService rideService, AuthService authService, Color activeGold, bool isDark, ThemeService theme) {
    return StreamBuilder<List<RideModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        final allRides = snapshot.data ?? [];
        final filteredRides = allRides.where((ride) => statuses.contains(ride.status)).toList();
        
        if (filteredRides.isEmpty) return _buildEmptyState('No records in this category.', activeGold, isDark);

        // Sort: Upcoming (Soonest first), Past (Most recent first)
        filteredRides.sort((a, b) {
          if (statuses.contains('completed')) return b.dateTime.compareTo(a.dateTime);
          return a.dateTime.compareTo(b.dateTime);
        });

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 10),
          physics: const BouncingScrollPhysics(),
          itemCount: filteredRides.length,
          itemBuilder: (context, index) {
            final ride = filteredRides[index];
            return FutureBuilder<UserModel?>(
              future: authService.getUserData(ride.driverId),
              builder: (context, driverSnap) {
                final driver = driverSnap.data;
                return _buildEnhancedMyRideCard(
                  context: context,
                  ride: ride,
                  driver: driver,
                  userId: userId,
                  rideService: rideService,
                  authService: authService,
                  gold: activeGold,
                  isDark: isDark,
                  theme: theme,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEnhancedMyRideCard({
    required BuildContext context,
    required RideModel ride,
    required UserModel? driver,
    required String userId,
    required RideService rideService,
    required AuthService authService,
    required Color gold,
    required bool isDark,
    required ThemeService theme,
  }) {
    final bool isCompleted = ride.status == 'completed' || ride.status == 'cancelled';
    final bool isOngoing = ride.status == 'ongoing';
    final bool isDriver = ride.driverId == userId;
    
    // Passenger Acceptance Status
    final bool isConfirmed = ride.passengers.contains(userId);
    final bool isPending = ride.pendingPassengers.contains(userId);
    final bool isWaitlisted = ride.waitlist.contains(userId);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassContainer(
        isDark: isDark,
        padding: const EdgeInsets.all(16),
        borderRadius: 20,
        child: InkWell(
          onLongPress: () => _confirmDelete(context, ride.id, userId, rideService),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => RideDetailsScreen(ride: ride))),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: gold.withOpacity(0.1),
                    backgroundImage: (driver?.profilePic != null) ? NetworkImage(driver!.profilePic!) : null,
                    child: driver?.profilePic == null ? Icon(Icons.person, color: gold) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                driver?.name ?? 'Loading...',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Passenger Confirmation Status Badge
                            if (!isDriver && !isCompleted && !isOngoing) ...[
                              if (isConfirmed) _buildStatusBadge('Confirmed', const Color(0xFF4DB6AC))
                              else if (isPending) _buildStatusBadge('Pending', Colors.orange)
                              else if (isWaitlisted) _buildStatusBadge('Waitlist', Colors.blueGrey),
                            ] else ...[
                              // Fallback to Trip Status Badge
                              if (ride.status == 'completed') _buildStatusBadge('COMPLETED', Colors.green)
                              else if (ride.status == 'cancelled') _buildStatusBadge('CANCELLED', Colors.red)
                              else if (isOngoing) _buildStatusBadge('ONGOING', Colors.blue)
                              else _buildStatusBadge('UPCOMING', gold),
                            ],
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Text('${driver?.averageRating.toStringAsFixed(1) ?? '5.0'}', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Column(
                    children: [
                      const Icon(Icons.circle, size: 8, color: Colors.tealAccent),
                      Container(height: 30, width: 1, color: gold.withOpacity(0.3)),
                      const Icon(Icons.circle, size: 8, color: Colors.orange),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(ride.pickupLocation.split(',').first, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            Text(DateFormat('hh:mm a').format(ride.dateTime), style: TextStyle(color: gold, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(ride.destination.split(',').first, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            Text(DateFormat('MMM d').format(ride.dateTime), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [Icon(Icons.person_outline, size: 16, color: gold), const SizedBox(width: 4), Text('${ride.availableSeats} Seats', style: const TextStyle(fontSize: 12, color: Colors.grey))]),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: gold.withOpacity(0.2), borderRadius: BorderRadius.circular(10), border: Border.all(color: gold.withOpacity(0.5))),
                    child: Text('K${ride.pricePerSeat}', style: TextStyle(color: gold, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ],
              ),
              if (ride.status == 'completed' && !isDriver)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final driver = await authService.getUserData(ride.driverId);
                        if (context.mounted && driver != null) {
                          showDialog(context: context, builder: (context) => RatingDialog(rideId: ride.id, revieweeId: ride.driverId, revieweeName: driver.name));
                        }
                      },
                      icon: const Icon(Icons.star_rounded, size: 18, color: Colors.black),
                      label: const Text('RATE DRIVER', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, Color gold, bool isDark) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.directions_car_outlined, size: 60, color: gold.withOpacity(0.3)), const SizedBox(height: 16), Text(message, style: TextStyle(color: isDark ? Colors.white38 : Colors.grey, fontWeight: FontWeight.bold))]));
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.5))),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  void _confirmDelete(BuildContext context, String rideId, String userId, RideService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Remove from History?', style: TextStyle(color: Colors.white)),
        content: const Text('This will remove the trip from your view.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(onPressed: () { service.hideRideForUser(rideId, userId); Navigator.pop(context); }, child: const Text('REMOVE', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}

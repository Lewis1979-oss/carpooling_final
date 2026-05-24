import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/ride_model.dart';
import '../models/user_model.dart';
import '../services/ride_service.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../widgets/glass_widgets.dart';
import 'ride_details_screen.dart';
import 'browse_rides_map_screen.dart';
import 'package:intl/intl.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  
  String _fromQuery = '';
  String _toQuery = '';

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() => _selectedTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rideService = RideService();
    final authService = Provider.of<AuthService>(context, listen: false);
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;
    final activeGold = themeService.goldAccent;
    final isTealTheme = themeService.appTheme == AppTheme.tealGold;

    return GlassScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                physics: const BouncingScrollPhysics(),
                children: [
                  const SizedBox(height: 10),
                  Text(
                    'Find a Ride',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Search for premium rides in your area',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 30),
                  _buildSearchCard(isDark, activeGold, themeService),
                  const SizedBox(height: 32),
                  _buildResultsHeader(isDark, activeGold),
                  const SizedBox(height: 16),
                  _buildRideList(rideService, authService, activeGold, isDark, isTealTheme),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchCard(bool isDark, Color gold, ThemeService theme) {
    return GlassContainer(
      isDark: isDark,
      padding: const EdgeInsets.all(20),
      borderRadius: 25,
      child: Column(
        children: [
          Row(
            children: [
              Column(
                children: [
                  Icon(Icons.radio_button_checked, color: gold, size: 20),
                  Container(height: 40, width: 1, color: gold.withOpacity(0.3)),
                  const Icon(Icons.location_on, color: Colors.tealAccent, size: 20),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    TextField(
                      controller: _fromController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: 'From',
                        labelStyle: TextStyle(color: gold.withOpacity(0.7)),
                        hintText: 'Your location',
                        hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                        border: InputBorder.none,
                      ),
                      onChanged: (v) => setState(() => _fromQuery = v.toLowerCase()),
                    ),
                    Divider(height: 1, color: gold.withOpacity(0.2)),
                    TextField(
                      controller: _toController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: 'To',
                        labelStyle: TextStyle(color: gold.withOpacity(0.7)),
                        hintText: 'Enter destination',
                        hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                        border: InputBorder.none,
                      ),
                      onChanged: (v) => setState(() => _toQuery = v.toLowerCase()),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildPickerButton(
                  icon: Icons.calendar_today_outlined,
                  label: 'Date & Time',
                  value: _selectedDate == null 
                      ? 'Today, 08:00 AM' 
                      : '${DateFormat('EEE, d MMM').format(_selectedDate!)}, ${_selectedTime?.format(context) ?? "08:00 AM"}',
                  onTap: () async {
                    await _selectDate(context);
                    if (mounted) await _selectTime(context);
                  },
                  isDark: isDark,
                  gold: gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: () {
                setState(() {});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 0,
              ),
              child: const Text('Search Rides', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerButton({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    required bool isDark,
    required Color gold,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: gold.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: gold),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(fontSize: 12, color: gold.withOpacity(0.8), fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                Icon(Icons.calendar_month, size: 18, color: gold),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsHeader(bool isDark, Color gold) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Available Rides',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const BrowseRidesMapScreen()),
            );
          },
          child: Text('Map View', style: TextStyle(color: gold, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildRideList(RideService rideService, AuthService authService, Color gold, bool isDark, bool isTeal) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const Center(child: Text('Please login to view rides.'));

    return StreamBuilder<UserModel?>(
      stream: authService.getUserStream(currentUser.uid),
      builder: (context, userSnap) {
        if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());
        final user = userSnap.data!;

        return StreamBuilder<List<RideModel>>(
          stream: rideService.getRides(user),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
            }
            
            final allRides = snapshot.data ?? [];
            
            List<RideModel> rides = allRides.where((ride) {
              bool matchesFrom = _fromQuery.isEmpty || ride.pickupLocation.toLowerCase().contains(_fromQuery);
              bool matchesTo = _toQuery.isEmpty || ride.destination.toLowerCase().contains(_toQuery);
              
              bool matchesDate = true;
              if (_selectedDate != null) {
                matchesDate = ride.dateTime.year == _selectedDate!.year &&
                              ride.dateTime.month == _selectedDate!.month &&
                              ride.dateTime.day == _selectedDate!.day;
              }
              
              return matchesFrom && matchesTo && matchesDate && ride.status == 'upcoming';
            }).toList();

            if (rides.isEmpty) {
              return _buildEmptyState('No rides found for your route.', gold);
            }

            return Column(
              children: rides.map((ride) => FutureBuilder<UserModel?>(
                future: authService.getUserData(ride.driverId),
                builder: (context, driverSnap) {
                  final driver = driverSnap.data;
                  return _buildEnhancedRideCard(context, ride, driver, gold, isDark, isTeal);
                },
              )).toList(),
            );
          },
        );
      }
    );
  }

  Widget _buildEnhancedRideCard(BuildContext context, RideModel ride, UserModel? driver, Color gold, bool isDark, bool isTeal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassContainer(
        isDark: isDark,
        padding: const EdgeInsets.all(16),
        borderRadius: 20,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => RideDetailsScreen(ride: ride)),
            );
          },
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
                        Text(
                          driver?.name ?? 'Loading...',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '4.8',
                              style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: gold.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: gold.withOpacity(0.5)),
                    ),
                    child: Text(
                      'K${ride.pricePerSeat}',
                      style: TextStyle(color: gold, fontWeight: FontWeight.bold, fontSize: 14),
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
                      Container(height: 20, width: 1, color: gold.withOpacity(0.3)),
                      const Icon(Icons.circle, size: 8, color: Colors.orange),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ride.pickupLocation.split(',').first,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          ride.destination.split(',').first,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        DateFormat('hh:mm a').format(ride.dateTime),
                        style: TextStyle(color: gold, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${ride.availableSeats} Seats left',
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, Color gold) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Icon(Icons.search_off, size: 60, color: gold.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

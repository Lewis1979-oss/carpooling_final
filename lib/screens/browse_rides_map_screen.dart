import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/ride_model.dart';
import '../models/user_model.dart';
import '../services/ride_service.dart';
import '../services/map_service.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../widgets/glass_widgets.dart';
import 'ride_details_screen.dart';

class BrowseRidesMapScreen extends StatefulWidget {
  const BrowseRidesMapScreen({super.key});

  @override
  State<BrowseRidesMapScreen> createState() => _BrowseRidesMapScreenState();
}

class _BrowseRidesMapScreenState extends State<BrowseRidesMapScreen> {
  final RideService _rideService = RideService();
  final MapController _mapController = MapController();
  
  RideModel? _selectedRide;
  LatLng? _currentLiveLocation;
  StreamSubscription<Position>? _positionSubscription;

  bool _isFollowingMe = false;
  bool _isCompassMode = false;
  StreamSubscription<CompassEvent>? _compassSubscription;

  @override
  void initState() {
    super.initState();
    _startLiveLocationTracking();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _compassSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _toggleLocationMode() {
    setState(() {
      if (!_isFollowingMe) {
        _isFollowingMe = true;
        _isCompassMode = false;
      } else if (!_isCompassMode) {
        _isCompassMode = true;
        _startCompassAndTilt();
      } else {
        _isFollowingMe = false;
        _isCompassMode = false;
        _stopCompassAndTilt();
      }
    });

    if (_isFollowingMe && _currentLiveLocation != null) {
      _mapController.move(_currentLiveLocation!, 15.0);
    }
  }

  void _startCompassAndTilt() {
    _compassSubscription?.cancel();
    _compassSubscription = FlutterCompass.events!.listen((event) {
      if (!mounted || !_isCompassMode) return;
      if (event.heading != null) {
        _mapController.rotate(-event.heading!);
      }
    });
  }

  void _stopCompassAndTilt() {
    _compassSubscription?.cancel();
    _mapController.rotate(0);
  }

  Future<void> _startLiveLocationTracking() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position pos = await Geolocator.getCurrentPosition();
        if (mounted) {
          setState(() => _currentLiveLocation = LatLng(pos.latitude, pos.longitude));
          _mapController.move(_currentLiveLocation!, 12.0);
        }

        _positionSubscription = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
        ).listen((Position pos) {
          if (mounted) {
            setState(() => _currentLiveLocation = LatLng(pos.latitude, pos.longitude));
            if (_isFollowingMe) {
              _mapController.move(_currentLiveLocation!, _mapController.camera.zoom);
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Live Location Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isDark = themeService.isDarkMode;
    final goldColor = themeService.goldAccent;
    final screenHeight = MediaQuery.of(context).size.height;

    return GlassScaffold(
      appBar: AppBar(
        title: const Text('Browse Available Rides', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(themeService.isSatelliteMode ? Icons.map : Icons.satellite_alt, color: goldColor),
            onPressed: () => themeService.toggleMapMode(),
          ),
        ],
      ),
      body: StreamBuilder<UserModel?>(
        stream: currentUserId != null ? authService.getUserStream(currentUserId) : Stream.value(null),
        builder: (context, userSnapshot) {
          final currentUser = userSnapshot.data;
          
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (currentUser == null) {
            return const Center(child: Text('Please login to view rides.'));
          }

          return StreamBuilder<List<RideModel>>(
            stream: _rideService.getRides(currentUser),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final rides = snapshot.data ?? [];

              return Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: const LatLng(-15.3875, 28.3228),
                      initialZoom: 12.0,
                      onTap: (_, __) => setState(() {
                        _selectedRide = null;
                      }),
                      onPositionChanged: (position, hasGesture) {
                        if (hasGesture && _isFollowingMe) {
                          setState(() {
                            _isFollowingMe = false;
                            _isCompassMode = false;
                          });
                          _stopCompassAndTilt();
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: themeService.mapUrl,
                        userAgentPackageName: 'com.example.carpool_final',
                      ),
                      if (themeService.isTrafficEnabled)
                        TileLayer(
                          urlTemplate: themeService.trafficUrl,
                          backgroundColor: Colors.transparent,
                          userAgentPackageName: 'com.example.carpool_final',
                        ),
                      MarkerLayer(
                        markers: [
                          if (_currentLiveLocation != null)
                            Marker(
                              point: _currentLiveLocation!,
                              width: 60, height: 60,
                              child: _buildBlurredLiveMarker(goldColor),
                            ),
                          ...rides.map((ride) {
                            final isSelected = _selectedRide?.id == ride.id;
                            return Marker(
                              point: LatLng(ride.pickupLat, ride.pickupLng),
                              width: 60,
                              height: 60,
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedRide = ride),
                                child: Transform.rotate(
                                  angle: 0.5,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.4),
                                          blurRadius: 10,
                                          offset: const Offset(2, 4),
                                        )
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.navigation,
                                      color: isSelected ? goldColor : Colors.white,
                                      size: isSelected ? 45 : 35,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ],
                  ),

                  Positioned(
                    bottom: (screenHeight * 0.4) + 20,
                    right: 20,
                    child: FloatingActionButton.small(
                      heroTag: "my_loc_browse",
                      onPressed: _toggleLocationMode,
                      backgroundColor: _isCompassMode ? Colors.blue : goldColor,
                      child: Icon(
                        _isCompassMode ? Icons.explore : (_isFollowingMe ? Icons.my_location : Icons.location_searching),
                        color: Colors.white,
                      ),
                    ),
                  ),
                  
                  if (_selectedRide != null)
                    Positioned(
                      bottom: 40,
                      left: 20,
                      right: 20,
                      child: _buildRidePreviewCard(_selectedRide!, isDark, goldColor),
                    ),
                ],
              );
            },
          );
        }
      ),
    );
  }

  Widget _buildBlurredLiveMarker(Color gold) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: gold.withOpacity(0.3),
              boxShadow: [BoxShadow(color: gold.withOpacity(0.5), blurRadius: 15, spreadRadius: 5)],
            ),
          ),
          Container(
            width: 12, height: 12,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }

  Widget _buildRidePreviewCard(RideModel ride, bool isDark, Color gold) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 25,
      isDark: isDark,
      accentColor: gold,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FutureBuilder<UserModel?>(
            future: authService.getUserData(ride.driverId),
            builder: (context, snapshot) {
              final driver = snapshot.data;
              return Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundImage: driver?.profilePic != null ? NetworkImage(driver!.profilePic!) : null,
                    child: driver?.profilePic == null ? const Icon(Icons.person) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver?.name ?? 'Driver',
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 18,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(Icons.star, color: gold, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              driver?.averageRating.toStringAsFixed(1) ?? '5.0',
                              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: gold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      'K${ride.pricePerSeat}',
                      style: TextStyle(color: gold, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ],
              );
            },
          ),
          const Divider(height: 30),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ride.pickupLocation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ride.destination,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RideDetailsScreen(ride: ride)),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: gold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text('VIEW RIDE DETAILS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

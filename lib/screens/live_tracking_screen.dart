import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/ride_model.dart';
import '../services/ride_service.dart';
import '../services/theme_service.dart';
import '../services/map_service.dart';
import '../services/safety_service.dart';
import '../config/safety_config.dart';
import '../widgets/glass_widgets.dart';

class LiveTrackingScreen extends StatefulWidget {
  final String rideId;
  final bool isDriver;

  const LiveTrackingScreen({
    super.key,
    required this.rideId,
    required this.isDriver,
  });

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final RideService _rideService = RideService();
  final MapService _mapService = MapService();
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionStream;
  LatLng? _currentLocation;
  double _distanceToDestination = 0;
  String _estimatedTime = "--";
  double _speed = 0;
  List<LatLng> _routePoints = [];
  bool _isFollowing = true;

  // Anomaly Detection State
  DateTime _lastMoveTime = DateTime.now();
  Timer? _anomalyCheckTimer;
  bool _isShowingSafetyCheck = false;
  Timer? _autoAlertTimer;
  int _countdownSeconds = 60;

  // High Risk Zone State
  final Set<String> _notifiedZones = {};

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndStart();
    _loadInitialRoute();
    _startAnomalyCheck();
  }

  Future<void> _loadInitialRoute() async {
    final ride = await _rideService.getRideById(widget.rideId).first;
    final data = await _mapService.getFullRouteData(
      LatLng(ride.pickupLat, ride.pickupLng),
      LatLng(ride.destinationLat, ride.destinationLng),
    );
    if (data != null && mounted) {
      setState(() {
        _routePoints = data.points;
      });
    }
  }

  Future<void> _checkPermissionsAndStart() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location services are disabled.")),
        );
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    if (widget.isDriver) {
      _startLocationUpdates();
    }
  }

  void _startLocationUpdates() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      _rideService.updateLiveLocation(
        widget.rideId,
        position.latitude,
        position.longitude,
      );
      if (mounted) {
        final newLoc = LatLng(position.latitude, position.longitude);
        setState(() {
          _currentLocation = newLoc;
          _speed = position.speed * 3.6; // Convert m/s to km/h
          
          if (_speed > 5.0) {
            _lastMoveTime = DateTime.now();
          }

          if (_isFollowing) {
            _mapController.move(_currentLocation!, _mapController.camera.zoom);
          }
        });

        // Check for entering High Risk Zones
        _checkHighRiskZones(newLoc);
      }
    });
  }

  void _checkHighRiskZones(LatLng pos) {
    if (!SafetyConfig.isLateNight()) return;

    for (var zone in SafetyConfig.highRiskZones) {
      double distance = Geolocator.distanceBetween(
        pos.latitude, pos.longitude,
        zone.center.latitude, zone.center.longitude
      );

      if (distance <= zone.radius && !_notifiedZones.contains(zone.name)) {
        _notifiedZones.add(zone.name);
        _triggerZoneWarning(zone);
      } else if (distance > zone.radius + 100) {
        // Reset if moved away so it can trigger again if re-entered (optional logic)
        _notifiedZones.remove(zone.name);
      }
    }
  }

  void _triggerZoneWarning(HighRiskZone zone) {
    HapticFeedback.vibrate();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "CAUTION: Entering ${zone.name}. ${zone.warningMessage}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _startAnomalyCheck() {
    _anomalyCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!SafetyConfig.isLateNight()) return;
      if (_isShowingSafetyCheck) return;

      final ride = await _rideService.getRideById(widget.rideId).first;
      if (ride.status != 'ongoing') return;

      final carPos = widget.isDriver 
          ? _currentLocation 
          : (ride.currentLat != null ? LatLng(ride.currentLat!, ride.currentLng!) : null);
      
      if (carPos == null) return;

      double distToDest = Geolocator.distanceBetween(
        carPos.latitude, carPos.longitude, 
        ride.destinationLat, ride.destinationLng
      );

      if (DateTime.now().difference(_lastMoveTime).inMinutes >= SafetyConfig.maxStoppedMinutes && distToDest > 200) {
        _triggerSafetyCheck(ride);
      }
    });
  }

  void _triggerSafetyCheck(RideModel ride) {
    if (_isShowingSafetyCheck) return;
    
    setState(() {
      _isShowingSafetyCheck = true;
      _countdownSeconds = 60;
    });

    HapticFeedback.vibrate();
    
    _autoAlertTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 0) {
        setState(() => _countdownSeconds--);
      } else {
        timer.cancel();
        _alertAdmin(ride);
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          content: GlassContainer(
            isDark: true,
            borderRadius: 25,
            accentColor: Colors.red,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 50),
                const SizedBox(height: 20),
                const Text("ARE YOU OKAY?", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 12),
                const Text(
                  "We noticed you've been stopped for a while. Please confirm you are safe.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 30),
                Text(
                  "Alerting Admin in $_countdownSeconds seconds...",
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    _autoAlertTimer?.cancel();
                    Navigator.pop(context);
                    setState(() {
                      _isShowingSafetyCheck = false;
                      _lastMoveTime = DateTime.now();
                    });
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 50)),
                  child: const Text("I'M SAFE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    _autoAlertTimer?.cancel();
                    Navigator.pop(context);
                    _alertAdmin(ride, isManual: true);
                  },
                  child: const Text("HELP ME", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _alertAdmin(RideModel ride, {bool isManual = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await SafetyService().reportIssue(
      ride.id, 
      user.uid, 
      isManual ? "USER REQUESTED HELP DURING STOP" : "ANOMALY DETECTED: UNEXPECTED STOP FOR > 5 MIN",
      isSOS: true
    );

    if (mounted) {
      if (_isShowingSafetyCheck) Navigator.of(context, rootNavigator: true).pop();
      setState(() => _isShowingSafetyCheck = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("ADMIN ALERTED! Stay calm, help is coming."),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 10),
        ),
      );
    }
  }

  void _calculateMetrics(RideModel ride, LatLng carPos) {
    double distanceInMeters = Geolocator.distanceBetween(
      carPos.latitude,
      carPos.longitude,
      ride.destinationLat,
      ride.destinationLng,
    );
    
    _distanceToDestination = distanceInMeters / 1000;

    // For non-driver, track movements to reset _lastMoveTime
    if (!widget.isDriver) {
      static LatLng? _prevCarPos;
      if (_prevCarPos != null) {
        double distMoved = Geolocator.distanceBetween(
          _prevCarPos!.latitude, _prevCarPos!.longitude,
          carPos.latitude, carPos.longitude
        );
        if (distMoved > 10) {
          _lastMoveTime = DateTime.now();
          _checkHighRiskZones(carPos);
        }
      }
      _prevCarPos = carPos;
    }

    double avgSpeed = _speed > 5 ? _speed : 40.0;
    double timeInHours = _distanceToDestination / avgSpeed;
    int timeInMinutes = (timeInHours * 60).round();

    if (timeInMinutes < 1) {
      _estimatedTime = "Arriving";
    } else if (timeInMinutes > 60) {
      int hours = timeInMinutes ~/ 60;
      int mins = timeInMinutes % 60;
      _estimatedTime = "${hours}h ${mins}m";
    } else {
      _estimatedTime = "$timeInMinutes min";
    }
  }

  void _shareRide(RideModel ride) async {
    final String shareUrl = "https://zedpool.app/track/${ride.id}";
    final String shareText = "I'm on a trip to ${ride.destination} via ZedPool! Track me live here: $shareUrl";
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassContainer(
        isDark: Theme.of(context).brightness == Brightness.dark,
        borderRadius: 30,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Share Ride Tracking", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareOption(
                  icon: Icons.copy,
                  label: "Copy Link",
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: shareUrl));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link copied to clipboard")));
                  },
                ),
                _buildShareOption(
                  icon: Icons.message,
                  label: "WhatsApp",
                  onTap: () async {
                    final Uri whatsappUrl = Uri.parse("whatsapp://send?text=${Uri.encodeComponent(shareText)}");
                    if (await canLaunchUrl(whatsappUrl)) {
                      await launchUrl(whatsappUrl);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("WhatsApp not installed")));
                    }
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: const Color(0xFFC0A060).withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: const Color(0xFFC0A060)),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _anomalyCheckTimer?.cancel();
    _autoAlertTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;
    final goldColor = themeService.goldAccent;
    final lightBlue = Colors.lightBlueAccent;
    final bool isLateNight = SafetyConfig.isLateNight();

    return GlassScaffold(
      appBar: AppBar(
        title: Text(
          widget.isDriver ? "Driving to Destination" : "Tracking Your Ride",
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        backgroundColor: (isDark ? Colors.black : Colors.white).withOpacity(0.7),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: goldColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(themeService.isSatelliteMode ? Icons.map : Icons.satellite_alt),
            onPressed: () => themeService.toggleMapMode(),
            tooltip: 'Toggle Satellite View',
          ),
          StreamBuilder<RideModel>(
            stream: _rideService.getRideById(widget.rideId),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return IconButton(
                  icon: Icon(Icons.share, color: goldColor),
                  onPressed: () => _shareRide(snapshot.data!),
                );
              }
              return const SizedBox();
            },
          ),
        ],
      ),
      body: StreamBuilder<RideModel>(
        stream: _rideService.getRideById(widget.rideId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading tracking data."));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final ride = snapshot.data!;
          final carPos = widget.isDriver 
              ? _currentLocation 
              : (ride.currentLat != null ? LatLng(ride.currentLat!, ride.currentLng!) : null);

          if (carPos != null) {
            _calculateMetrics(ride, carPos);
          }

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: carPos ?? LatLng(ride.pickupLat, ride.pickupLng),
                  initialZoom: 15.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                  onPositionChanged: (position, hasGesture) {
                    if (hasGesture) {
                      setState(() => _isFollowing = false);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: themeService.mapUrl,
                    userAgentPackageName: 'com.example.carpool_final',
                  ),
                  
                  if (isLateNight)
                    CircleLayer(
                      circles: SafetyConfig.highRiskZones.map((zone) => CircleMarker(
                        point: zone.center,
                        radius: zone.radius,
                        useRadiusInMeter: true,
                        color: Colors.red.withOpacity(0.3),
                        borderColor: Colors.red,
                        borderStrokeWidth: 2,
                      )).toList(),
                    ),

                  if (_routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          color: goldColor.withOpacity(0.6),
                          strokeWidth: 4.0,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(ride.pickupLat, ride.pickupLng),
                        child: const Icon(Icons.location_on, color: Colors.green, size: 35),
                      ),
                      Marker(
                        point: LatLng(ride.destinationLat, ride.destinationLng),
                        child: const Icon(Icons.location_on, color: Colors.red, size: 35),
                      ),
                      if (carPos != null)
                        Marker(
                          point: carPos,
                          width: 60,
                          height: 60,
                          child: Container(
                            decoration: BoxDecoration(
                              color: lightBlue.withOpacity(0.3),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(color: lightBlue.withOpacity(0.5), blurRadius: 10, spreadRadius: 2),
                              ],
                            ),
                            child: Icon(Icons.location_on, color: lightBlue, size: 35),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              
              if (!_isFollowing)
                Positioned(
                  top: 20,
                  right: 20,
                  child: FloatingActionButton.small(
                    onPressed: () => setState(() => _isFollowing = true),
                    backgroundColor: goldColor,
                    child: const Icon(Icons.my_location, color: Colors.white),
                  ),
                ),

              Positioned(
                bottom: 30,
                left: 20,
                right: 20,
                child: GlassContainer(
                  padding: const EdgeInsets.all(20),
                  borderRadius: 25,
                  isDark: isDark,
                  accentColor: goldColor,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLateNight)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.shield, color: Colors.orange, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                "NIGHT SAFETY MODE ACTIVE",
                                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: goldColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    ride.status.toUpperCase(),
                                    style: TextStyle(color: goldColor, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  ride.destination,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (widget.isDriver && ride.status == 'ongoing')
                            ElevatedButton(
                              onPressed: () async {
                                await _rideService.updateRideStatus(ride.id, 'completed');
                                if (mounted) Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text("FINISH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const Divider(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(Icons.timer_outlined, _estimatedTime, "EST. TIME"),
                          _buildStatItem(Icons.route_outlined, "${_distanceToDestination.toStringAsFixed(1)} km", "DISTANCE"),
                          _buildStatItem(Icons.speed, "${_speed.toStringAsFixed(0)} km/h", "SPEED"),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFC0A060), size: 22),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

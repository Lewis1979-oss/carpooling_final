import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:intl/intl.dart';
import '../models/ride_model.dart';
import '../models/user_model.dart';
import '../services/ride_service.dart';
import '../services/map_service.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../services/notification_service.dart';
import '../services/error_service.dart';
import '../config/safety_config.dart';
import '../widgets/glass_widgets.dart';

class PostRideScreen extends StatefulWidget {
  const PostRideScreen({super.key});

  @override
  _PostRideScreenState createState() => _PostRideScreenState();
}

class _PostRideScreenState extends State<PostRideScreen> {
  final _pickupController = TextEditingController();
  final _destinationController = TextEditingController();
  final _seatsController = TextEditingController();
  final _priceController = TextEditingController();
  final _searchController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  
  final _rideService = RideService();
  final _mapService = MapService();
  final _notificationService = NotificationService();
  final _authService = AuthService();
  final MapController _mapController = MapController();
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  LatLng? _pickupLatLng;
  LatLng? _destinationLatLng;
  LatLng? _currentLiveLocation; 
  StreamSubscription<Position>? _positionSubscription;
  
  bool _isSelectingPickup = true;
  bool _isLoading = false;
  List<SuggestionModel> _suggestions = [];
  
  DateTime _selectedDateTime = DateTime.now().add(const Duration(hours: 2));

  // Real Route Metrics
  double _realDistanceKm = 0.0;
  int _realDurationMin = 0;
  List<LatLng> _routePoints = [];

  // Comfort Preferences
  bool _ac = false;
  bool _smoking = false;
  bool _quiet = false;
  bool _music = false;

  // Premium Features
  bool _verifiedOnly = false;
  bool _ladiesOnly = false;
  UserModel? _userData;

  // Tilting & Compass State
  bool _isFollowingMe = false;
  bool _isCompassMode = false;
  StreamSubscription<CompassEvent>? _compassSubscription;

  @override
  void initState() {
    super.initState();
    _startLiveLocationTracking();
    _loadUserData();
    _updateDateTimeControllers();
  }

  void _updateDateTimeControllers() {
    _dateController.text = DateFormat('dd MMM yyyy').format(_selectedDateTime);
    _timeController.text = DateFormat('hh:mm a').format(_selectedDateTime);
    
    // Auto-check for late night when time changes
    if (SafetyConfig.isTimeLateNight(_selectedDateTime)) {
      if (!_verifiedOnly) {
        setState(() {
          _verifiedOnly = true;
        });
        _showLateNightAlert();
      }
    }
  }

  void _showLateNightAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: GlassContainer(
          isDark: true,
          borderRadius: 20,
          accentColor: Colors.orange,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.nightlight_round, color: Colors.orange, size: 40),
              const SizedBox(height: 15),
              const Text(
                'LATE NIGHT SECURITY',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
              ),
              const SizedBox(height: 10),
              const Text(
                'Rides between 21:00 and 04:00 are automatically set to "Verified Only" for your safety. A security PIN handshake will be required to start the trip.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('I UNDERSTAND', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final data = await _authService.getUserData(user.uid);
      if (mounted) setState(() => _userData = data);
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _compassSubscription?.cancel();
    _sheetController.dispose();
    _mapController.dispose();
    _pickupController.dispose();
    _destinationController.dispose();
    _seatsController.dispose();
    _priceController.dispose();
    _searchController.dispose();
    _dateController.dispose();
    _timeController.dispose();
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
          _mapController.move(_currentLiveLocation!, 13.0);
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

  void _onMapTap(LatLng point) async {
    final address = await _mapService.getAddressFromCoords(point);
    setState(() {
      if (_isSelectingPickup) {
        _pickupLatLng = point;
        _pickupController.text = address;
      } else {
        _destinationLatLng = point;
        _destinationController.text = address;
      }
    });

    if (_pickupLatLng != null && _destinationLatLng != null) {
      _updateRouteMetrics();
    }
  }

  Future<void> _updateRouteMetrics() async {
    if (_pickupLatLng == null || _destinationLatLng == null) return;
    
    final data = await _mapService.getFullRouteData(_pickupLatLng!, _destinationLatLng!);
    if (data != null && mounted) {
      setState(() {
        _routePoints = data.points;
        _realDistanceKm = data.distanceKm;
        _realDurationMin = data.durationMinutes;
      });
    }
  }

  void _onSearchChanged(String query) async {
    if (query.length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    final results = await _mapService.getAutocompleteSuggestions(query);
    setState(() => _suggestions = results);
  }

  void _selectSuggestion(SuggestionModel suggestion) {
    setState(() {
      if (_isSelectingPickup) {
        _pickupLatLng = suggestion.point;
        _pickupController.text = suggestion.label;
      } else {
        _destinationLatLng = suggestion.point;
        _destinationController.text = suggestion.label;
      }
      _suggestions = [];
      _searchController.clear();
      _mapController.move(suggestion.point, 15.0);
    });
    if (_pickupLatLng != null && _destinationLatLng != null) {
      _updateRouteMetrics();
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: isError ? Colors.red : Colors.green, behavior: SnackBarBehavior.floating));
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        _selectedDateTime = DateTime(picked.year, picked.month, picked.day, _selectedDateTime.hour, _selectedDateTime.minute);
        _updateDateTimeControllers();
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (picked != null) {
      setState(() {
        _selectedDateTime = DateTime(_selectedDateTime.year, _selectedDateTime.month, _selectedDateTime.day, picked.hour, picked.minute);
        _updateDateTimeControllers();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;
    final activeGold = themeService.goldAccent;
    final themeAccent = themeService.secondaryColor;
    final isTealTheme = themeService.appTheme == AppTheme.tealGold;
    final bool isLateNight = SafetyConfig.isTimeLateNight(_selectedDateTime);

    return GlassScaffold(
      appBar: AppBar(
        title: Text(
          'Post a Ride', 
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            color: isDark ? Colors.white : Colors.black87
          )
        ), 
        backgroundColor: Colors.transparent, 
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: activeGold, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          _buildAppBarAction(
            icon: themeService.isTrafficEnabled ? Icons.traffic : Icons.traffic_outlined,
            onPressed: () => themeService.toggleTraffic(),
            gold: activeGold,
            isDark: isDark,
          ),
          _buildAppBarAction(
            icon: themeService.isSatelliteMode ? Icons.map : Icons.satellite_alt,
            onPressed: () => themeService.toggleMapMode(),
            gold: activeGold,
            isDark: isDark,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // The Map (Full Screen)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(-15.3875, 28.3228), 
              initialZoom: 13.0, 
              onTap: (tapPosition, point) => _onMapTap(point),
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
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: themeAccent.withOpacity(0.8),
                      strokeWidth: 4,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (_currentLiveLocation != null) 
                    Marker(
                      point: _currentLiveLocation!,
                      width: 60,
                      height: 60,
                      child: _buildBlurredLiveMarker(themeAccent),
                    ),
                  if (_pickupLatLng != null) Marker(point: _pickupLatLng!, child: Icon(Icons.location_on, color: themeAccent, size: 45)),
                  if (_destinationLatLng != null) Marker(point: _destinationLatLng!, child: const Icon(Icons.location_on, color: Colors.orange, size: 45)),
                ],
              ),
            ],
          ),

          // Search and Tabs Overlay (Top)
          Positioned(
            top: 100, 
            left: 20, 
            right: 20, 
            child: Column(
              children: [
                GlassContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  borderRadius: 15,
                  isDark: isDark,
                  containerOpacity: 0.3, // Increased opacity for better visibility
                  borderWidth: 1.5,
                  borderOpacity: 0.3,
                  accentColor: themeAccent,
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Search for ${_isSelectingPickup ? "pickup" : "destination"}...',
                      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey, fontSize: 13),
                      border: InputBorder.none,
                      suffixIcon: Icon(Icons.search, color: themeAccent, size: 20),
                    ),
                  ),
                ),
                
                if (_suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: isDark ? (isTealTheme ? const Color(0xFF0D3B3B).withOpacity(0.9) : const Color(0xFF1A1A1A)) : Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: themeAccent.withOpacity(0.3)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) => ListTile(
                        dense: true,
                        title: Text(_suggestions[index].label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
                        onTap: () => _selectSuggestion(_suggestions[index]),
                      ),
                    ),
                  ),
                
                const SizedBox(height: 12),
                
                GlassContainer(
                  padding: const EdgeInsets.all(4), 
                  borderRadius: 30, 
                  isDark: isDark, 
                  containerOpacity: 0.3, // Increased opacity for better visibility
                  borderOpacity: 0.3,
                  accentColor: themeAccent,
                  child: Row(
                    children: [
                      _buildMapTab('PICKUP', _isSelectingPickup, () => setState(() {
                        _isSelectingPickup = true;
                        _suggestions = [];
                        _searchController.clear();
                      }), themeAccent), 
                      _buildMapTab('DESTINATION', !_isSelectingPickup, () => setState(() {
                        _isSelectingPickup = false;
                        _suggestions = [];
                        _searchController.clear();
                      }), themeAccent)
                    ]
                  )
                ),
              ],
            ),
          ),

          // My Location Button
          Positioned(
            bottom: 160, 
            right: 20,
            child: FloatingActionButton.small(
              heroTag: "my_loc_post",
              onPressed: _toggleLocationMode,
              backgroundColor: _isCompassMode ? Colors.blue : themeAccent,
              elevation: 4,
              child: Icon(
                _isCompassMode ? Icons.explore : (_isFollowingMe ? Icons.my_location : Icons.location_searching),
                color: Colors.white,
              ),
            ),
          ),

          // Pull-up Drawer for Ride Details
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.2, // Collapsed state
            minChildSize: 0.15,
            maxChildSize: 0.8, // Pull up to show everything
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  gradient: themeService.backgroundGradient,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
                  child: Column(
                    children: [
                      // Handlebar
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: themeAccent.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      
                      Text(
                        "RIDE DETAILS",
                        style: TextStyle(
                          color: themeAccent,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 25),

                      _buildLocationField(_pickupController, 'Pickup From', Icons.radio_button_checked, themeAccent, isDark, themeAccent),
                      const SizedBox(height: 12),
                      _buildLocationField(_destinationController, 'Destination', Icons.location_on, Colors.orange, isDark, themeAccent),
                      
                      if (_realDistanceKm > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 15),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildMetricChip(Icons.straighten, "${_realDistanceKm.toStringAsFixed(1)} KM", themeAccent, isDark),
                              const SizedBox(width: 15),
                              _buildMetricChip(Icons.access_time, "${_realDurationMin} MIN", themeAccent, isDark),
                            ],
                          ),
                        ),

                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: _buildInputBox(_seatsController, 'SEATS', Icons.event_seat, isDark, themeAccent)), 
                          const SizedBox(width: 16), 
                          Expanded(child: _buildInputBox(_priceController, 'PRICE (K)', Icons.payments_outlined, isDark, themeAccent))
                        ]
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _selectDate,
                              child: _buildInputBox(_dateController, 'DATE', Icons.calendar_today, isDark, themeAccent, readOnly: true),
                            ),
                          ), 
                          const SizedBox(width: 16), 
                          Expanded(
                            child: GestureDetector(
                              onTap: _selectTime,
                              child: _buildInputBox(_timeController, 'TIME', Icons.access_time, isDark, themeAccent, readOnly: true),
                            ),
                          )
                        ]
                      ),
                      const SizedBox(height: 25),
                      
                      // Safety & Privacy Section
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text("SAFETY & PRIVACY", style: TextStyle(color: themeAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSwitchTile(
                              "Verified Only", 
                              "Only approved passengers", 
                              Icons.verified_user, 
                              _verifiedOnly, 
                              isLateNight ? null : (val) => setState(() => _verifiedOnly = val), 
                              isLateNight ? Colors.orange : themeAccent, 
                              isDark
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (_userData?.gender?.toLowerCase() == 'female')
                            Expanded(
                              child: _buildSwitchTile(
                                "Lady-Pool", 
                                "Female passengers only", 
                                Icons.female, 
                                _ladiesOnly, 
                                (val) => setState(() => _ladiesOnly = val), 
                                Colors.pinkAccent, 
                                isDark
                              ),
                            ),
                        ],
                      ),
                      
                      const SizedBox(height: 25),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text("COMFORT PREFERENCES", style: TextStyle(color: themeAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                        children: [
                          _buildPreferenceChip(Icons.ac_unit, 'A/C', _ac, (val) => setState(() => _ac = val), themeAccent, isDark), 
                          _buildPreferenceChip(Icons.smoke_free, 'No Smoke', _smoking, (val) => setState(() => _smoking = val), themeAccent, isDark), 
                          _buildPreferenceChip(Icons.volume_off, 'Quiet', _quiet, (val) => setState(() {
                            _quiet = val;
                            if (_quiet) _music = false; 
                          }), themeAccent, isDark), 
                          _buildPreferenceChip(Icons.music_note, 'Music', _music, (val) => setState(() {
                            _music = val;
                            if (_music) _quiet = false; 
                          }), themeAccent, isDark)
                        ]
                      ),
                      const SizedBox(height: 35),
                      SizedBox(
                        width: double.infinity, 
                        height: 55, 
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitRide, 
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeAccent, 
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            elevation: 0,
                          ), 
                          child: _isLoading 
                            ? const CircularProgressIndicator(color: Colors.white) 
                            : const Text('POST PREMIUM RIDE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1))
                        )
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarAction({required IconData icon, required VoidCallback onPressed, required Color gold, required bool isDark}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.5),
        shape: BoxShape.circle,
        border: Border.all(color: gold.withOpacity(0.2)),
      ),
      child: IconButton(
        icon: Icon(icon, color: gold, size: 20),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildBlurredLiveMarker(Color color) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.2),
            ),
          ),
          Container(
            width: 12, height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(IconData icon, String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildMapTab(String label, bool active, VoidCallback onTap, Color color) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap, 
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10), 
          decoration: BoxDecoration(
            color: active ? color : Colors.transparent, 
            borderRadius: BorderRadius.circular(25)
          ), 
          child: Text(
            label, 
            textAlign: TextAlign.center, 
            style: TextStyle(
              color: active ? Colors.white : Colors.grey, 
              fontWeight: FontWeight.bold, 
              fontSize: 11
            )
          )
        )
      )
    );
  }

  Widget _buildPreferenceChip(IconData icon, String label, bool selected, Function(bool) onToggle, Color color, bool isDark) {
    return GestureDetector(
      onTap: () => onToggle(!selected), 
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200), 
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), 
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)), 
          borderRadius: BorderRadius.circular(15), 
          border: Border.all(color: selected ? color : Colors.transparent)
        ), 
        child: Column(
          children: [
            Icon(icon, color: selected ? color : Colors.grey, size: 22), 
            const SizedBox(height: 6), 
            Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: selected ? color : Colors.grey))
          ]
        )
      )
    );
  }

  Widget _buildSwitchTile(String title, String sub, IconData icon, bool value, Function(bool)? onChanged, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: value ? color : Colors.grey, size: 20),
              Switch.adaptive(
                value: value, 
                onChanged: onChanged,
                activeColor: color,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
          Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 9)),
        ],
      ),
    );
  }

  Widget _buildLocationField(TextEditingController controller, String label, IconData icon, Color color, bool isDark, Color accent) {
    return Container(
      padding: const EdgeInsets.all(12), 
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: accent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20), 
          const SizedBox(width: 12), 
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: accent, fontWeight: FontWeight.bold)), 
                TextField(
                  controller: controller, 
                  readOnly: true, 
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87), 
                  decoration: const InputDecoration(isDense: true, border: InputBorder.none)
                )
              ]
            )
          )
        ]
      )
    );
  }

  Widget _buildInputBox(TextEditingController controller, String label, IconData icon, bool isDark, Color accent, {bool readOnly = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
      decoration: BoxDecoration(
        color: isDark ? Colors.white30.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: accent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: accent, fontWeight: FontWeight.bold)), 
          TextField(
            controller: controller, 
            keyboardType: TextInputType.number, 
            readOnly: readOnly,
            enabled: !readOnly,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87), 
            decoration: InputDecoration(
              isDense: true, 
              border: InputBorder.none, 
              prefixIcon: Icon(icon, size: 18, color: accent.withOpacity(0.5)), 
              prefixIconConstraints: const BoxConstraints(minWidth: 30)
            )
          )
        ]
      )
    );
  }

  void _submitRide() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_userData?.vehicleInfo == null) { _showSnackBar('Please add your Vehicle details in Profile settings first.'); return; }
    if (_pickupLatLng != null && _destinationLatLng != null && _seatsController.text.isNotEmpty && _priceController.text.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        final ride = RideModel(
          id: '', 
          driverId: user.uid, 
          pickupLocation: _pickupController.text, 
          pickupLat: _pickupLatLng!.latitude, 
          pickupLng: _pickupLatLng!.longitude, 
          destination: _destinationController.text, 
          destinationLat: _destinationLatLng!.latitude, 
          destinationLng: _destinationLatLng!.longitude, 
          dateTime: _selectedDateTime,
          availableSeats: int.parse(_seatsController.text), 
          totalSeats: int.parse(_seatsController.text), 
          pricePerSeat: double.parse(_priceController.text), 
          vehicleInfo: _userData!.vehicleInfo, 
          preferences: {'ac': _ac, 'smoking': _smoking, 'quiet': _quiet, 'music': _music}, 
          estimatedDistance: _realDistanceKm, 
          estimatedDuration: _realDurationMin,
          verifiedOnly: _verifiedOnly,
          ladiesOnly: _ladiesOnly,
        );
        await _rideService.postRide(ride);
        await _notificationService.showNotification(title: 'Ride Posted!', body: 'Your premium ride is now live!');
        if (mounted) { _showSnackBar('Premium ride posted!', isError: false); Navigator.pop(context); }
      } catch (e) { 
        if (mounted) {
          final message = ErrorService.getFriendlyMessage(e);
          _showSnackBar(message); 
        }
      } finally { if (mounted) setState(() => _isLoading = false); }
    } else { _showSnackBar('Please fill in all details.'); }
  }
}

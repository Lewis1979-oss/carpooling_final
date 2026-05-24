import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/ride_model.dart';
import '../services/admin_service.dart';
import '../services/map_service.dart';
import '../services/theme_service.dart';
import 'glass_widgets.dart';

class AdminMapWidget extends StatefulWidget {
  const AdminMapWidget({super.key});

  @override
  State<AdminMapWidget> createState() => _AdminMapWidgetState();
}

class _AdminMapWidgetState extends State<AdminMapWidget> {
  final AdminService _adminService = AdminService();
  final MapService _mapService = MapService();
  final MapController _mapController = MapController();
  RideModel? _selectedRide;
  List<LatLng> _selectedRoutePoints = [];
  bool _isLoadingRoute = false;

  Future<void> _onRideSelected(RideModel ride) async {
    if (_selectedRide?.id == ride.id) return;

    setState(() {
      _selectedRide = ride;
      _isLoadingRoute = true;
      _selectedRoutePoints = [];
    });

    final points = await _mapService.getRouteCoordinates(
      LatLng(ride.pickupLat, ride.pickupLng),
      LatLng(ride.destinationLat, ride.destinationLng),
    );

    if (mounted && _selectedRide?.id == ride.id) {
      setState(() {
        _selectedRoutePoints = points;
        _isLoadingRoute = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;
    final goldColor = themeService.goldAccent;

    return StreamBuilder<List<RideModel>>(
      stream: _adminService.getAllRides(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        // Filter to only show active (non-completed) rides on the map
        final rides = (snapshot.data ?? []).where((r) => r.status != 'completed' && r.status != 'cancelled').toList();

        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(-15.3875, 28.3228),
                initialZoom: 11.0,
                onTap: (_, __) => setState(() {
                  _selectedRide = null;
                  _selectedRoutePoints = [];
                }),
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
                if (_selectedRoutePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _selectedRoutePoints,
                        color: goldColor,
                        strokeWidth: 4.0,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: rides.expand((ride) {
                    final isSelected = _selectedRide?.id == ride.id;
                    List<Marker> markers = [];
                    
                    // Pickup Marker
                    markers.add(
                      Marker(
                        point: LatLng(ride.pickupLat, ride.pickupLng),
                        width: 40,
                        height: 40,
                        child: GestureDetector(
                          onTap: () => _onRideSelected(ride),
                          child: Icon(
                            Icons.location_on,
                            color: isSelected ? Colors.green : Colors.green.withOpacity(0.6),
                            size: isSelected ? 35 : 25,
                          ),
                        ),
                      ),
                    );

                    // Destination Marker (only if selected)
                    if (isSelected) {
                      markers.add(
                        Marker(
                          point: LatLng(ride.destinationLat, ride.destinationLng),
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_on, color: Colors.red, size: 35),
                        ),
                      );
                    }

                    // Live Car Marker (for active journeys) - Premium Top-Down White Car
                    if (ride.currentLat != null && ride.currentLng != null && (ride.status == 'ongoing' || ride.status == 'started')) {
                      markers.add(
                        Marker(
                          point: LatLng(ride.currentLat!, ride.currentLng!),
                          width: 50,
                          height: 50,
                          child: Transform.rotate(
                            angle: 0.5, // Slight rotation as requested
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
                              child: const Icon(
                                Icons.navigation, 
                                color: Colors.white, 
                                size: 35
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    
                    return markers;
                  }).toList(),
                ),
              ],
            ),
            
            if (_isLoadingRoute)
              Positioned(
                top: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: GlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    isDark: isDark,
                    accentColor: goldColor,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2, color: goldColor),
                        ),
                        const SizedBox(width: 10),
                        const Text('Fetching route...', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),

            if (_selectedRide != null)
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: _buildRideDetailsCard(_selectedRide!, isDark, goldColor, themeService),
              ),
            
            Positioned(
              top: 10,
              right: 10,
              child: GlassContainer(
                padding: const EdgeInsets.all(10),
                isDark: isDark,
                accentColor: goldColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem(Icons.location_on, Colors.green, 'Pickup'),
                    _buildLegendItem(Icons.location_on, Colors.red, 'Destination'),
                    _buildLegendItem(Icons.navigation, Colors.white, 'Live Car'),
                    const Divider(color: Colors.white10),
                    _buildControlToggle(
                      icon: Icons.traffic,
                      label: 'TRAFFIC',
                      isActive: themeService.isTrafficEnabled,
                      onTap: () => themeService.toggleTraffic(),
                      goldColor: goldColor,
                    ),
                    const SizedBox(height: 4),
                    _buildControlToggle(
                      icon: themeService.isSatelliteMode ? Icons.map : Icons.satellite_alt,
                      label: themeService.isSatelliteMode ? 'STREET' : 'SATELLITE',
                      isActive: true,
                      onTap: () => themeService.toggleMapMode(),
                      goldColor: goldColor,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControlToggle({required IconData icon, required String label, required bool isActive, required VoidCallback onTap, required Color goldColor}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? goldColor.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: goldColor.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: goldColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: goldColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(IconData icon, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildRideDetailsCard(RideModel ride, bool isDark, Color gold, ThemeService theme) {
    return GlassContainer(
      padding: const EdgeInsets.all(15),
      isDark: isDark,
      accentColor: gold,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${ride.pickupLocation} ➔ ${ride.destination}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    color: isDark ? Colors.white : Colors.black87, 
                    fontSize: 14,
                    fontFamily: theme.fontFamily,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: gold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ride.status.toUpperCase(),
                  style: TextStyle(color: gold, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PRICE', style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold, fontFamily: theme.fontFamily)),
                  Text('K${ride.pricePerSeat}', style: TextStyle(fontWeight: FontWeight.w900, color: gold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SEATS', style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold, fontFamily: theme.fontFamily)),
                  Text('${ride.availableSeats}/${ride.totalSeats}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PASSENGERS', style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold, fontFamily: theme.fontFamily)),
                  Text('${ride.passengers.length} Joined', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

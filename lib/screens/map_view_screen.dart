import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../services/map_service.dart';
import '../services/theme_service.dart';
import '../config/keys.dart';
import '../widgets/glass_widgets.dart';

class MapViewScreen extends StatefulWidget {
  final LatLng startPoint;
  final LatLng endPoint;

  const MapViewScreen({
    super.key,
    required this.startPoint,
    required this.endPoint,
  });

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  final MapService _mapService = MapService();
  List<LatLng> _routePoints = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    final points = await _mapService.getRouteCoordinates(widget.startPoint, widget.endPoint);
    if (mounted) {
      setState(() {
        _routePoints = points;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;
    final goldColor = themeService.goldAccent;

    return GlassScaffold(
      appBar: AppBar(
        title: const Text('Ride Route', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: (isDark ? Colors.black : Colors.white).withOpacity(0.7),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(themeService.isTrafficEnabled ? Icons.traffic : Icons.traffic_outlined),
            onPressed: () => themeService.toggleTraffic(),
            tooltip: 'Toggle Traffic Layer',
          ),
          IconButton(
            icon: Icon(themeService.isSatelliteMode ? Icons.map : Icons.satellite_alt),
            onPressed: () => themeService.toggleMapMode(),
            tooltip: 'Toggle Satellite View',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: widget.startPoint,
              initialZoom: 13.0,
            ),
            children: [
              // Base Map (follows theme automatically via mapUrl)
              TileLayer(
                urlTemplate: themeService.mapUrl,
                userAgentPackageName: 'com.example.carpool_final',
              ),
              // Traffic Layer (Transparent)
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
                      color: isDark ? goldColor : Colors.blue.shade700,
                      strokeWidth: 5.0,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.startPoint,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_on, color: Colors.green, size: 40),
                  ),
                  Marker(
                    point: widget.endPoint,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                  ),
                ],
              ),
            ],
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: GlassContainer(
              borderRadius: 20,
              isDark: isDark,
              accentColor: goldColor,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.circle, color: Colors.green, size: 12),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Pickup Location',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Divider(color: isDark ? Colors.white10 : Colors.grey[300]),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.red, size: 12),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Destination',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

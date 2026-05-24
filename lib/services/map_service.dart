import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../config/keys.dart';

class RouteData {
  final List<LatLng> points;
  final double distanceKm;
  final int durationMinutes;

  RouteData({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
  });
}

class SuggestionModel {
  final String label;
  final LatLng point;

  SuggestionModel({required this.label, required this.point});
}

class MapService {
  // Get route between two points using OpenRouteService with metadata
  Future<RouteData?> getFullRouteData(LatLng start, LatLng end) async {
    final String url = 'https://api.openrouteservice.org/v2/directions/driving-car?api_key=${AppKeys.orsApiKey}&start=${start.longitude},${start.latitude}&end=${end.longitude},${end.latitude}';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final feature = data['features'][0];
        
        // Extract coordinates
        final List coords = feature['geometry']['coordinates'];
        final points = coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
        
        // Extract distance and duration from the summary
        final summary = feature['properties']['summary'];
        final double distanceKm = (summary['distance'] ?? 0.0) / 1000.0;
        final int durationMinutes = ((summary['duration'] ?? 0.0) / 60.0).round();
        
        return RouteData(
          points: points,
          distanceKm: distanceKm,
          durationMinutes: durationMinutes,
        );
      } else {
        print("ORS Routing Error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("ORS Exception: $e");
    }
    return null;
  }

  // Get Search Suggestions (Autocomplete) using MapTiler Geocoding API
  // This will find Shops, Schools, Companies, and Restaurants as requested.
  Future<List<SuggestionModel>> getAutocompleteSuggestions(String query) async {
    if (query.length < 3) return [];
    
    // Using MapTiler Geocoding API for high-detail search
    final String url = 'https://api.maptiler.com/geocoding/${Uri.encodeComponent(query)}.json?key=${AppKeys.mapTilerKey}&fuzzyMatch=true&limit=5';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List features = data['features'] ?? [];
        
        return features.map((f) {
          final List center = f['center'];
          return SuggestionModel(
            label: f['place_name'] ?? "Unknown Location",
            point: LatLng(center[1].toDouble(), center[0].toDouble()),
          );
        }).toList();
      }
    } catch (e) {
      print("Autocomplete Error: $e");
    }
    return [];
  }

  // Backward compatibility for existing code
  Future<List<LatLng>> getRouteCoordinates(LatLng start, LatLng end) async {
    final data = await getFullRouteData(start, end);
    return data?.points ?? [];
  }

  // Reverse Geocoding: Get address from coordinates
  Future<String> getAddressFromCoords(LatLng point) async {
    final String nominatimUrl = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}&zoom=18&addressdetails=1';
    
    try {
      final response = await http.get(
        Uri.parse(nominatimUrl),
        headers: {'User-Agent': 'ZedPool_App'}, 
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'];
        if (address != null) {
          final road = address['road'] ?? address['suburb'] ?? address['neighbourhood'] ?? '';
          final city = address['city'] ?? address['town'] ?? address['village'] ?? '';
          
          if (road.isNotEmpty && city.isNotEmpty) {
            return "$road, $city";
          } else if (data['display_name'] != null) {
            final parts = data['display_name'].split(',');
            if (parts.length > 2) {
              return "${parts[0].trim()}, ${parts[1].trim()}";
            }
            return data['display_name'];
          }
        }
      }
    } catch (e) {
      print("Nominatim Geocoding Error: $e");
    }

    final String orsUrl = 'https://api.openrouteservice.org/geocode/reverse?api_key=${AppKeys.orsApiKey}&point.lon=${point.longitude}&point.lat=${point.latitude}';
    
    try {
      final response = await http.get(Uri.parse(orsUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['features'] != null && data['features'].isNotEmpty) {
          return data['features'][0]['properties']['label'] ?? "Location found";
        }
      }
    } catch (e) {
      print("ORS Geocoding Error: $e");
    }

    return "Location near ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}";
  }
}

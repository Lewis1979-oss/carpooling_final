import 'package:latlong2/latlong.dart';

class SafetyConfig {
  // Time window for "Late Night" features (9 PM to 4 AM)
  static const int lateNightStartHour = 21;
  static const int lateNightEndHour = 4;

  // Twilio Configuration
  static const String twilioAccountSid = 'AC878de002cf6eb41007e302ee9f627222';
  static const String twilioAuthToken = '3c63abdcde9b92d7f973c0d75aab78de';
  static const String twilioFromNumber = '+19787929076';
  static const String adminEmergencyNumber = '+260964256282';

  // Check-in settings
  static const int checkInIntervalMinutes = 15;
  static const int maxMissedCheckIns = 2;

  // Anomaly detection thresholds
  static const int maxStoppedMinutes = 5;
  static const double maxRouteDeviationMeters = 500.0;

  // High-Risk Areas (Populated from Firestore at startup)
  static List<HighRiskZone> highRiskZones = [];

  static bool isLateNight() {
    final hour = DateTime.now().hour;
    return hour >= lateNightStartHour || hour < lateNightEndHour;
  }

  // Check if a specific time is late night
  static bool isTimeLateNight(DateTime time) {
    final hour = time.hour;
    return hour >= lateNightStartHour || hour < lateNightEndHour;
  }
}

class HighRiskZone {
  final String name;
  final LatLng center;
  final double radius; // meters
  final String warningMessage;

  HighRiskZone({
    required this.name,
    required this.center,
    required this.radius,
    required this.warningMessage,
  });

  factory HighRiskZone.fromMap(Map<String, dynamic> data) {
    double lat = 0;
    double lng = 0;
    
    if (data['center'] is Map) {
      lat = (data['center']['lat'] ?? 0).toDouble();
      lng = (data['center']['lng'] ?? 0).toDouble();
    } else {
      lat = data['center'].latitude;
      lng = data['center'].longitude;
    }

    return HighRiskZone(
      name: data['name'] ?? 'Unknown Risk Zone',
      center: LatLng(lat, lng),
      radius: (data['radius'] ?? 1000).toDouble(),
      warningMessage: data['warningMessage'] ?? 'Exercise caution in this area.',
    );
  }
}

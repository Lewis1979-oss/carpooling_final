import 'package:cloud_firestore/cloud_firestore.dart';

class RideModel {
  final String id;
  final String driverId;
  final String pickupLocation;
  final double pickupLat;
  final double pickupLng;
  final String destination;
  final double destinationLat;
  final double destinationLng;
  final DateTime dateTime;
  final int availableSeats;
  final int totalSeats;
  final double pricePerSeat;
  final List<String> passengers;
  final List<String> pendingPassengers;
  final List<String> paidPassengers;
  final List<String> waitlist; 
  final List<String> deletedBy; 
  final double? currentLat;
  final double? currentLng;
  final String status;
  
  // New "Pro" Features
  final Map<String, dynamic>? vehicleInfo;
  final Map<String, bool> preferences; // {ac: true, smoking: false, etc}
  final double? estimatedDistance; // in km
  final int? estimatedDuration; // in minutes
  final String? notes;
  final String rideType; // 'one-way' or 'round-trip'
  
  // Safety & Filter Features
  final bool verifiedOnly; 
  final bool ladiesOnly;   
  
  // Late Night Security
  final String? pinCode;
  final bool isLateNight;

  RideModel({
    required this.id,
    required this.driverId,
    required this.pickupLocation,
    required this.pickupLat,
    required this.pickupLng,
    required this.destination,
    required this.destinationLat,
    required this.destinationLng,
    required this.dateTime,
    required this.availableSeats,
    required this.totalSeats,
    required this.pricePerSeat,
    this.passengers = const [],
    this.pendingPassengers = const [],
    this.paidPassengers = const [],
    this.waitlist = const [],
    this.deletedBy = const [],
    this.currentLat,
    this.currentLng,
    this.status = 'upcoming',
    this.vehicleInfo,
    this.preferences = const {
      'ac': false,
      'smoking': false,
      'quiet': false,
      'music': false,
    },
    this.estimatedDistance,
    this.estimatedDuration,
    this.notes,
    this.rideType = 'one-way',
    this.verifiedOnly = false,
    this.ladiesOnly = false,
    this.pinCode,
    this.isLateNight = false,
  });

  factory RideModel.fromMap(Map<String, dynamic>? data, String documentId) {
    if (data == null) {
      return RideModel(
        id: documentId,
        driverId: '',
        pickupLocation: 'Unknown',
        pickupLat: 0,
        pickupLng: 0,
        destination: 'Unknown',
        destinationLat: 0,
        destinationLng: 0,
        dateTime: DateTime.now(),
        availableSeats: 0,
        totalSeats: 0,
        pricePerSeat: 0,
        status: 'cancelled',
      );
    }

    return RideModel(
      id: documentId,
      driverId: data['driverId'] ?? '',
      pickupLocation: data['pickupLocation'] ?? 'Unknown Location',
      pickupLat: (data['pickupLat'] ?? 0.0).toDouble(),
      pickupLng: (data['pickupLng'] ?? 0.0).toDouble(),
      destination: data['destination'] ?? 'Unknown Destination',
      destinationLat: (data['destinationLat'] ?? 0.0).toDouble(),
      destinationLng: (data['destinationLng'] ?? 0.0).toDouble(),
      dateTime: data['dateTime'] != null 
          ? (data['dateTime'] as Timestamp).toDate() 
          : DateTime.now(),
      availableSeats: data['availableSeats'] ?? 0,
      totalSeats: data['totalSeats'] ?? (data['availableSeats'] ?? 0),
      pricePerSeat: (data['pricePerSeat'] ?? 0).toDouble(),
      passengers: List<String>.from(data['passengers'] ?? []),
      pendingPassengers: List<String>.from(data['pendingPassengers'] ?? []),
      paidPassengers: List<String>.from(data['paidPassengers'] ?? []),
      waitlist: List<String>.from(data['waitlist'] ?? []),
      deletedBy: List<String>.from(data['deletedBy'] ?? []),
      currentLat: data['currentLat'] != null ? (data['currentLat'] as num).toDouble() : null,
      currentLng: data['currentLng'] != null ? (data['currentLng'] as num).toDouble() : null,
      status: data['status'] ?? 'upcoming',
      vehicleInfo: data['vehicleInfo'] != null ? Map<String, dynamic>.from(data['vehicleInfo']) : null,
      preferences: data['preferences'] != null 
          ? Map<String, bool>.from(data['preferences']) 
          : {'ac': false, 'smoking': false, 'quiet': false, 'music': false},
      estimatedDistance: data['estimatedDistance'] != null ? (data['estimatedDistance'] as num).toDouble() : null,
      estimatedDuration: data['estimatedDuration'] != null ? (data['estimatedDuration'] as num).toInt() : null,
      notes: data['notes'],
      rideType: data['rideType'] ?? 'one-way',
      verifiedOnly: data['verifiedOnly'] ?? false,
      ladiesOnly: data['ladiesOnly'] ?? false,
      pinCode: data['pinCode'],
      isLateNight: data['isLateNight'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'pickupLocation': pickupLocation,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'destination': destination,
      'destinationLat': destinationLat,
      'destinationLng': destinationLng,
      'dateTime': Timestamp.fromDate(dateTime),
      'availableSeats': availableSeats,
      'totalSeats': totalSeats,
      'pricePerSeat': pricePerSeat,
      'passengers': passengers,
      'pendingPassengers': pendingPassengers,
      'paidPassengers': paidPassengers,
      'waitlist': waitlist,
      'deletedBy': deletedBy,
      'currentLat': currentLat,
      'currentLng': currentLng,
      'status': status,
      'vehicleInfo': vehicleInfo,
      'preferences': preferences,
      'estimatedDistance': estimatedDistance,
      'estimatedDuration': estimatedDuration,
      'notes': notes,
      'rideType': rideType,
      'verifiedOnly': verifiedOnly,
      'ladiesOnly': ladiesOnly,
      'pinCode': pinCode,
      'isLateNight': isLateNight,
    };
  }
}

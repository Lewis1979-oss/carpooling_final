import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? profilePic;
  final String? idCardUrl;
  final String verificationStatus;
  final String vehicleVerificationStatus;
  final String role;
  final double averageRating;
  final int ratingCount;
  final String? emergencyContact;
  final bool isVerified;
  final double walletBalance;
  final int zedPoints;
  final double totalDistanceTravelled;
  final Map<String, dynamic>? vehicleInfo;
  final String? fcmToken;
  final List<String> badges;
  final String? gender; // Added for Lady-Pool feature
  
  // New Functional Fields
  final String? bio; 
  final bool hidePhoneNumber;
  final bool biometricEnabled;
  final bool notificationsEnabled;

  // Status Fields
  final bool isOnline;
  final DateTime? lastSeen;

  // Admin Management Fields
  final bool isBlocked;
  final DateTime? createdAt;
  
  // Payment Verification Field
  final bool verificationFeePaid;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.profilePic,
    this.idCardUrl,
    this.verificationStatus = 'unverified',
    this.vehicleVerificationStatus = 'unverified',
    this.role = 'user',
    this.averageRating = 0.0,
    this.ratingCount = 0,
    this.emergencyContact,
    this.isVerified = false,
    this.walletBalance = 0.0,
    this.zedPoints = 0,
    this.totalDistanceTravelled = 0.0,
    this.vehicleInfo,
    this.fcmToken,
    this.badges = const [],
    this.gender,
    this.bio,
    this.hidePhoneNumber = false,
    this.biometricEnabled = true,
    this.notificationsEnabled = true,
    this.isOnline = false,
    this.lastSeen,
    this.isBlocked = false,
    this.createdAt,
    this.verificationFeePaid = false,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String documentId) {
    return UserModel(
      id: documentId,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'],
      profilePic: data['profilePic'],
      idCardUrl: data['idCardUrl'],
      verificationStatus: data['verificationStatus'] ?? 'unverified',
      vehicleVerificationStatus: data['vehicleVerificationStatus'] ?? 'unverified',
      role: data['role'] ?? 'user',
      averageRating: (data['averageRating'] ?? 0.0).toDouble(),
      ratingCount: data['ratingCount'] ?? 0,
      emergencyContact: data['emergencyContact'],
      isVerified: data['isVerified'] ?? false,
      walletBalance: (data['walletBalance'] ?? 0.0).toDouble(),
      zedPoints: data['zedPoints'] ?? 0,
      totalDistanceTravelled: (data['totalDistanceTravelled'] ?? 0.0).toDouble(),
      vehicleInfo: data['vehicleInfo'] != null ? Map<String, dynamic>.from(data['vehicleInfo']) : null,
      fcmToken: data['fcmToken'],
      badges: List<String>.from(data['badges'] ?? []),
      gender: data['gender'],
      bio: data['bio'],
      hidePhoneNumber: data['hidePhoneNumber'] ?? false,
      biometricEnabled: data['biometricEnabled'] ?? true,
      notificationsEnabled: data['notificationsEnabled'] ?? true,
      isOnline: data['isOnline'] ?? false,
      lastSeen: data['lastSeen'] != null ? (data['lastSeen'] as Timestamp).toDate() : null,
      isBlocked: data['isBlocked'] ?? false,
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : null,
      verificationFeePaid: data['verificationFeePaid'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'profilePic': profilePic,
      'idCardUrl': idCardUrl,
      'verificationStatus': verificationStatus,
      'vehicleVerificationStatus': vehicleVerificationStatus,
      'role': role,
      'averageRating': averageRating,
      'ratingCount': ratingCount,
      'emergencyContact': emergencyContact,
      'isVerified': isVerified,
      'walletBalance': walletBalance,
      'zedPoints': zedPoints,
      'totalDistanceTravelled': totalDistanceTravelled,
      'vehicleInfo': vehicleInfo,
      'fcmToken': fcmToken,
      'badges': badges,
      'gender': gender,
      'bio': bio,
      'hidePhoneNumber': hidePhoneNumber,
      'biometricEnabled': biometricEnabled,
      'notificationsEnabled': notificationsEnabled,
      'isOnline': isOnline,
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
      'isBlocked': isBlocked,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'verificationFeePaid': verificationFeePaid,
    };
  }
}

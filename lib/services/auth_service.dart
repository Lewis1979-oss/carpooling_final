import 'dart:io';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/chat_model.dart';
import '../config/keys.dart';
import 'chat_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  
  late final Stream<User?> user;

  AuthService._internal() {
    user = _auth.authStateChanges();
  }

  // Update user presence status
  Future<void> updateUserPresence(bool isOnline) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _db.collection('users').doc(uid).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Update Presence Error: $e");
    }
  }

  Future<String?> _uploadToCloudinary(File file, String folder) async {
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/${AppKeys.cloudinaryCloudName}/image/upload');
      
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = AppKeys.cloudinaryUploadPreset
        ..fields['folder'] = folder
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);
        final jsonResponse = jsonDecode(responseString);
        return jsonResponse['secure_url'];
      } else {
        print("Cloudinary Upload Error: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Cloudinary Exception: $e");
      return null;
    }
  }

  Future<void> updateUserProfile({
    required String uid,
    String? name,
    String? email,
    String? phone,
    String? emergencyContact,
    String? bio,
    bool? hidePhoneNumber,
    bool? biometricEnabled,
    bool? notificationsEnabled,
    Map<String, dynamic>? vehicleInfo,
    File? profileImage,
  }) async {
    try {
      Map<String, dynamic> updates = {};
      
      if (name != null) updates['name'] = name;
      if (phone != null) updates['phone'] = phone;
      if (emergencyContact != null) updates['emergencyContact'] = emergencyContact;
      if (bio != null) updates['bio'] = bio;
      if (hidePhoneNumber != null) updates['hidePhoneNumber'] = hidePhoneNumber;
      if (biometricEnabled != null) updates['biometricEnabled'] = biometricEnabled;
      if (notificationsEnabled != null) updates['notificationsEnabled'] = notificationsEnabled;
      if (vehicleInfo != null) updates['vehicleInfo'] = vehicleInfo;

      if (email != null && email.isNotEmpty && email != _auth.currentUser?.email) {
        try {
          await _auth.currentUser?.verifyBeforeUpdateEmail(email);
          updates['email'] = email; 
        } on FirebaseAuthException catch (e) {
          if (e.code == 'requires-recent-login') {
            throw 'For security, please log out and log back in to change your email address.';
          }
          rethrow;
        }
      }

      if (profileImage != null) {
        String? downloadUrl = await _uploadToCloudinary(profileImage, 'user_profiles');
        if (downloadUrl != null) {
          updates['profilePic'] = downloadUrl;
        }
      }

      if (updates.isNotEmpty) {
        await _db.collection('users').doc(uid).update(updates);
      }
    } catch (e) {
      print("Update Profile Error: ${e.toString()}");
      rethrow;
    }
  }

  Future<void> submitForVerification({
    required String uid,
    required String userName,
    File? licenseImage,
    File? vehicleImage,
  }) async {
    try {
      String? licenseUrl;
      String? vehicleUrl;

      if (licenseImage != null) {
        licenseUrl = await _uploadToCloudinary(licenseImage, 'verifications/licenses');
      }
      if (vehicleImage != null) {
        vehicleUrl = await _uploadToCloudinary(vehicleImage, 'verifications/vehicles');
      }

      Map<String, dynamic> updates = {};
      if (licenseUrl != null) {
        updates['idCardUrl'] = licenseUrl;
        updates['verificationStatus'] = 'pending';
      }
      if (vehicleUrl != null) {
        updates['vehicleVerificationStatus'] = 'pending';
        // Update vehicleInfo photoUrl if vehicleInfo exists
        DocumentSnapshot userDoc = await _db.collection('users').doc(uid).get();
        if (userDoc.exists) {
          Map<String, dynamic>? currentVehicleInfo = (userDoc.data() as Map<String, dynamic>)['vehicleInfo'];
          if (currentVehicleInfo != null) {
             currentVehicleInfo['photoUrl'] = vehicleUrl;
             updates['vehicleInfo'] = currentVehicleInfo;
          } else {
             updates['vehicleInfo'] = {'photoUrl': vehicleUrl};
          }
        }
      }

      if (updates.isNotEmpty) {
        await _db.collection('users').doc(uid).update(updates);

        // Send to Admin Chat
        final adminSnapshot = await _db.collection('users').where('role', isEqualTo: 'admin').limit(1).get();
        if (adminSnapshot.docs.isNotEmpty) {
          final adminId = adminSnapshot.docs.first.id;
          final chatService = ChatService();
          final chatId = chatService.getPrivateChatId(uid, adminId);

          if (licenseUrl != null) {
            await chatService.sendPrivateMessage(
              chatId,
              MessageModel(
                id: '',
                senderId: uid,
                senderName: userName,
                text: 'Driver License Verification Request',
                timestamp: DateTime.now(),
                imageUrl: licenseUrl,
                isImage: true,
              ),
              adminId,
            );
          }

          if (vehicleUrl != null) {
            await chatService.sendPrivateMessage(
              chatId,
              MessageModel(
                id: '',
                senderId: uid,
                senderName: userName,
                text: 'Vehicle Verification Request',
                timestamp: DateTime.now(),
                imageUrl: vehicleUrl,
                isImage: true,
              ),
              adminId,
            );
          }
        }
      }
    } catch (e) {
      print("Verification Submission Error: $e");
      rethrow;
    }
  }

  Future<UserCredential?> signUp(
    String email, 
    String password, 
    String name, 
    {String? emergencyContact, File? profileImage}
  ) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      
      User? user = result.user;

      if (user != null) {
        String? profilePicUrl;
        
        if (profileImage != null) {
          profilePicUrl = await _uploadToCloudinary(profileImage, 'user_profiles');
        }

        await _db.collection('users').doc(user.uid).set({
          'name': name,
          'email': email,
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
          'emergencyContact': emergencyContact,
          'profilePic': profilePicUrl,
          'walletBalance': 0.0,
          'averageRating': 5.0,
          'isVerified': false,
          'zedPoints': 0,
          'totalDistanceTravelled': 0.0,
          'badges': [],
          'verificationStatus': 'unverified',
          'vehicleVerificationStatus': 'unverified',
          'bio': '',
          'hidePhoneNumber': false,
          'biometricEnabled': true,
          'notificationsEnabled': true,
          'isOnline': true,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }
      return result;
    } catch (e) {
      print("Sign Up Error: ${e.toString()}");
      rethrow;
    }
  }

  Future<UserCredential?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      if (result.user != null) {
        await updateUserPresence(true);
      }
      return result;
    } catch (e) {
      print("Sign In Error: ${e.toString()}");
      rethrow;
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential result = await _auth.signInWithCredential(credential);
      User? user = result.user;

      if (user != null) {
        DocumentSnapshot doc = await _db.collection('users').doc(user.uid).get();
        if (!doc.exists) {
          await _db.collection('users').doc(user.uid).set({
            'name': user.displayName ?? 'Google User',
            'email': user.email,
            'role': 'user',
            'createdAt': FieldValue.serverTimestamp(),
            'profilePic': user.photoURL,
            'walletBalance': 0.0,
            'averageRating': 5.0,
            'isVerified': false,
            'zedPoints': 0,
            'totalDistanceTravelled': 0.0,
            'badges': [],
            'verificationStatus': 'unverified',
            'vehicleVerificationStatus': 'unverified',
            'bio': '',
            'hidePhoneNumber': false,
            'biometricEnabled': true,
            'notificationsEnabled': true,
            'isOnline': true,
            'lastSeen': FieldValue.serverTimestamp(),
          });
        } else {
          await updateUserPresence(true);
        }
      }
      return result;
    } catch (e) {
      print("Google Sign In Error: ${e.toString()}");
      rethrow;
    }
  }

  Future<void> verifyPhone({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  Future<UserCredential?> signInWithCredential(PhoneAuthCredential credential) async {
    try {
      UserCredential result = await _auth.signInWithCredential(credential);
      User? user = result.user;

      if (user != null) {
        DocumentSnapshot doc = await _db.collection('users').doc(user.uid).get();
        if (!doc.exists) {
          await _db.collection('users').doc(user.uid).set({
            'name': 'Phone User', 
            'phone': user.phoneNumber,
            'email': '',
            'role': 'user',
            'createdAt': FieldValue.serverTimestamp(),
            'walletBalance': 0.0,
            'averageRating': 5.0,
            'isVerified': false,
            'zedPoints': 0,
            'totalDistanceTravelled': 0.0,
            'badges': [],
            'verificationStatus': 'unverified',
            'vehicleVerificationStatus': 'unverified',
            'bio': '',
            'hidePhoneNumber': false,
            'biometricEnabled': true,
            'notificationsEnabled': true,
            'isOnline': true,
            'lastSeen': FieldValue.serverTimestamp(),
          });
        } else {
          await updateUserPresence(true);
        }
      }
      return result;
    } catch (e) {
      print("Phone Sign In Error: ${e.toString()}");
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print("Password Reset Error: ${e.toString()}");
      rethrow;
    }
  }

  Future<void> signOut() async {
    await updateUserPresence(false);
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<UserModel?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
    } catch (e) {
      print("Get User Data Error: ${e.toString()}");
    }
    return null;
  }

  Stream<UserModel?> getUserStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    });
  }
}

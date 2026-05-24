import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> updateProfile(String uid, {String? name, File? image}) async {
    Map<String, dynamic> data = {};
    if (name != null) data['name'] = name;

    if (image != null) {
      final ref = _storage.ref().child('user_profiles').child('$uid.jpg');
      await ref.putFile(image);
      data['profilePic'] = await ref.getDownloadURL();
    }

    if (data.isNotEmpty) {
      await _db.collection('users').doc(uid).update(data);
    }
  }

  Future<void> updateProfilePic(String uid, File image) async {
    await updateProfile(uid, image: image);
  }

  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
  }

  Future<UserModel?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
    } catch (e) {
      print("Get User Data Error: \${e.toString()}");
    }
    return null;
  }
}

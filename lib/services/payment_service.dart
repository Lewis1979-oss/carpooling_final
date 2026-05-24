import 'dart:convert';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

enum PaymentProvider { mtn, airtel }

class PaymentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // --- SET THIS TO 'true' TO TEST WITHOUT REAL API CALLS ---
  final bool useMockMode = true; 

  // --- MTN MoMo API Configuration ---
  final String _mtnSubscriptionKey = "fa777129ab78492e9ae75ece16b58ef5";
  final String _mtnApiUser = "ac24420c-7b15-4467-a8e1-b5f9391ce390";
  final String _mtnApiKey = "6028682a36b349b1897e9ae75ece16b5"; 
  
  final String _targetEnvironment = "sandbox"; 
  final String _mtnBaseUrl = "https://sandbox.momodeveloper.mtn.com";

  // --- Airtel Money API Configuration (Placeholders) ---
  final String _airtelClientId = "YOUR_AIRTEL_CLIENT_ID";
  final String _airtelClientSecret = "YOUR_AIRTEL_CLIENT_SECRET";
  final String _airtelBaseUrl = "https://openapi.airtel.africa"; // Use sandbox URL for testing

  Future<String?> _getMTNAccessToken() async {
    if (useMockMode) return "mock_mtn_token";

    final String auth = base64Encode(utf8.encode('$_mtnApiUser:$_mtnApiKey'));
    try {
      final response = await http.post(
        Uri.parse('$_mtnBaseUrl/collection/token/'),
        headers: {
          'Authorization': 'Basic $auth',
          'Ocp-Apim-Subscription-Key': _mtnSubscriptionKey,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['access_token'];
      }
    } catch (e) {
      debugPrint("MTN Token Error: $e");
    }
    return null;
  }

  Future<String?> _getAirtelAccessToken() async {
    if (useMockMode) return "mock_airtel_token";
    
    try {
      final response = await http.post(
        Uri.parse('$_airtelBaseUrl/auth/oauth2/token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "client_id": _airtelClientId,
          "client_secret": _airtelClientSecret,
          "grant_type": "client_credentials"
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['access_token'];
      }
    } catch (e) {
      debugPrint("Airtel Token Error: $e");
    }
    return null;
  }

  Future<String?> requestToPay({
    required String phoneNumber, 
    required double amount, 
    required String currency,
    required PaymentProvider provider,
    String? rideId,
  }) async {
    String? referenceId;
    if (useMockMode) {
      debugPrint("SIMULATION: Initiating ${provider.name.toUpperCase()} payment for $phoneNumber");
      referenceId = "mock_ref_${provider.name}_${const Uuid().v4()}";
    } else {
      if (provider == PaymentProvider.mtn) {
        referenceId = await _requestMTNPay(phoneNumber, amount, currency);
      } else {
        referenceId = await _requestAirtelPay(phoneNumber, amount, currency);
      }
    }

    if (referenceId != null) {
      await _logTransaction(referenceId, phoneNumber, amount, provider, rideId);
    }
    return referenceId;
  }

  Future<void> _logTransaction(String ref, String phone, double amount, PaymentProvider provider, String? rideId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _db.collection('users').doc(user.uid).collection('payments').doc(ref).set({
      'referenceId': ref,
      'phoneNumber': phone,
      'amount': amount,
      'provider': provider.name,
      'rideId': rideId,
      'status': 'PENDING',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<String?> _requestMTNPay(String phoneNumber, double amount, String currency) async {
    final token = await _getMTNAccessToken();
    if (token == null) return null;

    final String referenceId = const Uuid().v4(); 
    try {
      final response = await http.post(
        Uri.parse('$_mtnBaseUrl/collection/v1_0/requesttopay'),
        headers: {
          'Authorization': 'Bearer $token',
          'X-Reference-Id': referenceId,
          'X-Target-Environment': _targetEnvironment,
          'Ocp-Apim-Subscription-Key': _mtnSubscriptionKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "amount": amount.toStringAsFixed(2),
          "currency": currency,
          "externalId": DateTime.now().millisecondsSinceEpoch.toString(),
          "payer": {"partyIdType": "MSISDN", "partyId": phoneNumber},
          "payerMessage": "ZedPool Ride",
          "payeeNote": "Carpooling Payment"
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 202) return referenceId; 
    } catch (e) {
      debugPrint("MTN Pay Error: $e");
    }
    return null;
  }

  Future<String?> _requestAirtelPay(String phoneNumber, double amount, String currency) async {
    final token = await _getAirtelAccessToken();
    if (token == null) return null;

    final String transactionId = const Uuid().v4();
    try {
      final response = await http.post(
        Uri.parse('$_airtelBaseUrl/merchant/v1/payments/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'X-Country': 'ZM',
          'X-Currency': currency,
        },
        body: jsonEncode({
          "reference": "ZedPool Ride",
          "subscriber": {
            "country": "ZM",
            "currency": currency,
            "msisdn": phoneNumber
          },
          "transaction": {
            "amount": amount,
            "id": transactionId
          }
        }),
      );
      if (response.statusCode == 200) return transactionId;
    } catch (e) {
      debugPrint("Airtel Pay Error: $e");
    }
    return null;
  }

  Future<String> checkPaymentStatus(String referenceId, PaymentProvider provider) async {
    String status = "FAILED";
    if (useMockMode) {
      await Future.delayed(const Duration(seconds: 4));
      status = "SUCCESSFUL";
    } else {
      if (provider == PaymentProvider.mtn) {
        status = await _checkMTNStatus(referenceId);
      } else {
        status = await _checkAirtelStatus(referenceId);
      }
    }

    await updateTransactionStatus(referenceId, status);
    return status;
  }

  Future<void> updateTransactionStatus(String ref, String status) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await _db.collection('users').doc(user.uid).collection('payments').doc(ref).update({
        'status': status,
      });
    } catch (e) {
      debugPrint("Error updating payment status in DB: $e");
    }
  }

  Future<String> _checkMTNStatus(String referenceId) async {
    final token = await _getMTNAccessToken();
    if (token == null) return "FAILED";

    try {
      final response = await http.get(
        Uri.parse('$_mtnBaseUrl/collection/v1_0/requesttopay/$referenceId'),
        headers: {
          'Authorization': 'Bearer $token',
          'X-Target-Environment': _targetEnvironment,
          'Ocp-Apim-Subscription-Key': _mtnSubscriptionKey,
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['status']; 
      }
    } catch (e) {
      debugPrint("MTN Status Error: $e");
    }
    return "FAILED";
  }

  Future<String> _checkAirtelStatus(String transactionId) async {
    final token = await _getAirtelAccessToken();
    if (token == null) return "FAILED";

    try {
      final response = await http.get(
        Uri.parse('$_airtelBaseUrl/standard/v1/payments/$transactionId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final status = jsonDecode(response.body)['data']['transaction']['status'];
        return status == 'TS' ? 'SUCCESSFUL' : 'FAILED';
      }
    } catch (e) {
      debugPrint("Airtel Status Error: $e");
    }
    return "FAILED";
  }
}

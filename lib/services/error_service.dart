import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class ErrorService {
  static String getFriendlyMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No account found with this email. Please check your spelling or register a new account.';
        case 'wrong-password':
          return 'Incorrect password. Please try again or reset your password if you have forgotten it.';
        case 'email-already-in-use':
          return 'This email is already registered. Try logging in or use a different email address.';
        case 'invalid-email':
          return 'The email address is not valid. Please enter a correct email format (e.g., name@example.com).';
        case 'weak-password':
          return 'Your password is too weak. Please use at least 6 characters, including numbers or symbols for better security.';
        case 'user-disabled':
          return 'This account has been disabled. Please contact support for assistance.';
        case 'too-many-requests':
          return 'Too many failed attempts. Please wait a few minutes before trying again to protect your security.';
        case 'operation-not-allowed':
          return 'This sign-in method is currently disabled. Please try another way to log in.';
        case 'network-request-failed':
          return 'Connection error. Please check your internet connection and try again.';
        case 'invalid-credential':
          return 'Invalid login details. Please double-check your email and password.';
        case 'requires-recent-login':
          return 'For security, please log out and log back in before performing this action.';
        case 'invalid-phone-number':
          return 'The phone number provided is not valid. Please check the number and country code.';
        case 'credential-already-in-use':
          return 'This phone number or email is already linked to another account.';
        case 'channel-error':
          return 'Authentication service is temporarily unavailable. Please try again in a moment.';
        default:
          return error.message ?? 'An unexpected security error occurred. Please try again.';
      }
    }

    if (error is PlatformException) {
      if (error.code == 'network_error') {
        return 'Network error. Please ensure you have a stable internet connection.';
      }
      return error.message ?? 'A system error occurred. Please try restarting the app.';
    }

    // Generic error handling
    String errorStr = error.toString().toLowerCase();
    if (errorStr.contains('network') || errorStr.contains('http') || errorStr.contains('socket')) {
      return 'Internet connection lost. Please check your Wi-Fi or mobile data and try again.';
    }
    if (errorStr.contains('timeout')) {
      return 'The request took too long. Please try again when you have a stronger signal.';
    }
    if (errorStr.contains('permission')) {
      return 'Permission denied. Please enable the required permissions in your phone settings.';
    }

    return 'Something went wrong. Please try again, or contact support if the problem persists.';
  }
}

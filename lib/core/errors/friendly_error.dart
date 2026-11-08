import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

String friendlyError(Object e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'A club with this email already exists. Try signing in.';
      case 'weak-password':
        return 'Choose a stronger password.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a bit and try again.';
      case 'network-request-failed':
        return 'No internet connection.';
      case 'account-exists-with-different-credential':
        return 'This email already has a password account. Sign in with your email and password instead.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled. Turn it on in Firebase: Authentication, Sign-in method.';
      case 'popup-blocked':
        return 'Your browser blocked the Google sign-in window. Allow pop-ups and try again.';
      case 'requires-recent-login':
        return 'Please sign in again and retry.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }
  if (e is FirebaseException) {
    if (e.code == 'permission-denied' || e.code == 'unauthorized') {
      return 'Not allowed. Make sure your email is verified, or this record may be locked (voided).';
    }
    if (e.code == 'unavailable') return 'Cannot reach the server. Check your connection.';
    return e.message ?? 'Something went wrong.';
  }
  if (e is FormatException) return e.message;
  return 'Something went wrong. Please try again.';
}

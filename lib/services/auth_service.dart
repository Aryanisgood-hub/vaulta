import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../core/constants/google_config.dart';

class AuthService {
  AuthService(this._auth);
  final FirebaseAuth _auth;

  Future<void> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  /// Registers a club account and sends the verification email.
  Future<void> register(String clubName, String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    await cred.user!.updateDisplayName(clubName.trim());
    await cred.user!.sendEmailVerification();
  }

  Future<void> resendVerification() async => _auth.currentUser?.sendEmailVerification();
  Future<void> reloadUser() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.getIdToken(true); // fresh token so the rules see email_verified
    await user.reload();
  }
  Future<void> sendReset(String email) => _auth.sendPasswordResetEmail(email: email.trim());
  Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        await GoogleSignIn.instance.signOut(); // so the account chooser shows next time
      } catch (_) {}
    }
    await _auth.signOut();
  }

  static bool _googleReady = false;

  /// "Continue with Google". Works for new and returning clubs.
  /// Returns normally (without signing in) if the user cancels.
  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      try {
        await _auth.signInWithPopup(GoogleAuthProvider());
      } on FirebaseAuthException catch (e) {
        if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') return;
        rethrow;
      }
      return;
    }
    if (googleServerClientId.startsWith('PASTE_')) {
      throw const FormatException(
          'Google sign-in is not set up yet. Add the Web client ID in lib/core/constants/google_config.dart.');
    }
    final google = GoogleSignIn.instance;
    if (!_googleReady) {
      await google.initialize(serverClientId: googleServerClientId);
      _googleReady = true;
    }
    try {
      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const FormatException('Google did not return a sign-in token. Check the Web client ID and SHA-1 setup.');
      }
      await _auth.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      throw FormatException('Google sign-in failed (${e.code.name}). Check the Google setup steps in the README.');
    }
  }

  Future<void> changePassword(String current, String next) async {
    final user = _auth.currentUser!;
    final cred = EmailAuthProvider.credential(email: user.email!, password: current);
    await user.reauthenticateWithCredential(cred);
    await user.updatePassword(next);
  }
}

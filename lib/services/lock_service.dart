import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// App lock using the phone's own fingerprint / face / PIN / pattern.
class LockService {
  final _auth = LocalAuthentication();

  Future<bool> supported() async {
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock Vaulta',
        options: const AuthenticationOptions(stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }
}

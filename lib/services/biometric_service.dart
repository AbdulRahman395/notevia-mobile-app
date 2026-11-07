import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_lock_service.dart';

/// What the phone can unlock with, for labels and icons.
class PhoneUnlockInfo {
  const PhoneUnlockInfo({required this.available, required this.label, required this.icon});

  /// The phone has a secure lock (fingerprint, face, PIN, pattern or password)
  final bool available;

  /// "fingerprint", "Face ID", "face unlock" or "screen lock"
  final String label;
  final IconData icon;

  static const none = PhoneUnlockInfo(available: false, label: 'screen lock', icon: Icons.lock_outline);
}

/// Unlock Notevia with the phone's own lock (fingerprint, face, or the phone's
/// PIN / pattern), like WhatsApp.
///
/// The server only accepts the Notevia PIN, so when this is turned on the PIN
/// is kept in the phone's secure storage (Android Keystore / iOS Keychain).
/// Unlocking asks the phone to confirm it's you, reads the PIN back and sends
/// it to the server exactly like a typed PIN.
class BiometricService {
  static final _auth = LocalAuthentication();
  static const _storage = FlutterSecureStorage();
  static const _pinKey = 'notevia_pin';
  static const _enabledKey = 'phone_unlock_enabled';

  static Future<PhoneUnlockInfo> info() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return PhoneUnlockInfo.none;
      final types = await _auth.getAvailableBiometrics();
      if (types.contains(BiometricType.face)) {
        final isIos = TargetPlatform.iOS == defaultTargetPlatform;
        return PhoneUnlockInfo(
          available: true,
          label: isIos ? 'Face ID' : 'face unlock',
          icon: Icons.face_outlined,
        );
      }
      if (types.isNotEmpty) {
        return const PhoneUnlockInfo(available: true, label: 'fingerprint', icon: Icons.fingerprint);
      }
      return const PhoneUnlockInfo(available: true, label: 'screen lock', icon: Icons.lock_open_outlined);
    } catch (_) {
      return PhoneUnlockInfo.none;
    }
  }

  static Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_enabledKey) != true) return false;
      return await _storage.containsKey(key: _pinKey);
    } catch (_) {
      return false;
    }
  }

  /// Shows the phone's prompt. Returns false if the user cancelled.
  static Future<bool> confirmIdentity(String reason) async {
    try {
      return await AppLockService().runExcused(
        () => _auth.authenticate(
          localizedReason: reason,
          biometricOnly: false, // allow the phone's PIN / pattern too
          persistAcrossBackgrounding: true,
        ),
      );
    } on LocalAuthException catch (e) {
      if (e.code == LocalAuthExceptionCode.userCanceled ||
          e.code == LocalAuthExceptionCode.systemCanceled ||
          e.code == LocalAuthExceptionCode.timeout) {
        return false;
      }
      rethrow;
    }
  }

  /// Save the PIN behind the phone lock. Call only with a PIN the server accepted.
  static Future<bool> enable(String pin) async {
    final ok = await confirmIdentity('Confirm it’s you to turn on phone unlock');
    if (!ok) return false;
    await _storage.write(key: _pinKey, value: pin);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);
    return true;
  }

  /// Ask the phone to confirm it's you, then return the saved PIN (null if cancelled).
  static Future<String?> readPin() async {
    final ok = await confirmIdentity('Unlock Notevia');
    if (!ok) return null;
    return _storage.read(key: _pinKey);
  }

  static const _staleKey = 'phone_unlock_stale';

  /// The saved PIN stopped working (it was changed, e.g. on the web).
  /// Forget it, but remember that phone unlock should come back with the new PIN.
  static Future<void> markStale() async {
    await disable();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_staleKey, true);
    } catch (_) {}
  }

  static Future<bool> isStale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_staleKey) == true;
    } catch (_) {
      return false;
    }
  }

  /// After a stale PIN: save the newly typed (server-accepted) PIN behind the
  /// phone lock again. One fingerprint check; if the user cancels, it stays off.
  static Future<bool> resync(String pin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_staleKey);
      return await enable(pin);
    } catch (_) {
      return false;
    }
  }

  /// The PIN was changed in the app: keep phone unlock working with the new one.
  /// The person just proved they know the PIN, so no fingerprint check is needed.
  static Future<void> replacePin(String pin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasOn = prefs.getBool(_enabledKey) == true || prefs.getBool(_staleKey) == true;
      if (!wasOn) return;
      await _storage.write(key: _pinKey, value: pin);
      await prefs.setBool(_enabledKey, true);
      await prefs.remove(_staleKey);
    } catch (_) {}
  }

  /// Forget the saved PIN (sign out, PIN change, or switched off).
  static Future<void> disable() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_enabledKey);
      await prefs.remove(_staleKey);
      await _storage.delete(key: _pinKey);
    } catch (_) {}
  }
}

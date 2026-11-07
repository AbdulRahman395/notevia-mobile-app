import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'app_lock_service.dart';
import 'biometric_service.dart';
import 'draft_service.dart';
import 'google_auth_service.dart';
import 'heartbeat_service.dart';
import 'token_service.dart';

/// The steps every PIN screen shares: verify, start the session, sign out.
class Session {
  /// Check a PIN with the server. Returns an error message, or null on success.
  static Future<String?> verifyPin(String pin) async {
    final authToken = await TokenService.getAuthToken();
    if (authToken == null || authToken.isEmpty) {
      return 'Your sign-in expired. Sign in again.';
    }
    try {
      final result = await ApiService.verifyPIN(authToken, pin);
      if (result['success'] == true) {
        final data = result['data'] ?? {};
        await opened((data['accessToken'] ?? data['token'] ?? '').toString());
        return null;
      }
      return (result['message'] ?? 'Incorrect PIN').toString();
    } catch (_) {
      return 'Couldn’t reach Notevia. Check your connection.';
    }
  }

  /// Unlock with the phone's fingerprint / face / screen lock.
  /// Returns an error message, '' if the user cancelled, or null on success.
  static Future<String?> unlockWithPhone() async {
    String? pin;
    try {
      pin = await BiometricService.readPin();
    } catch (_) {
      return 'Phone unlock isn’t available right now. Use your PIN.';
    }
    if (pin == null) return '';
    final error = await verifyPin(pin);
    if (error != null && !error.startsWith('Couldn’t reach')) {
      // The saved PIN no longer matches (PIN was changed on the web).
      // The next typed PIN will be saved again (see LockScreen).
      await BiometricService.markStale();
      return 'Your PIN changed. Enter the new PIN once to keep phone unlock.';
    }
    return error;
  }

  /// A PIN was accepted and the server gave us an access token.
  static Future<void> opened(String accessToken) async {
    if (accessToken.isNotEmpty) {
      await TokenService.storeAccessToken(accessToken);
      final heartbeat = HeartbeatService()..updateToken(accessToken);
      heartbeat.startHeartbeat();
    }
    final lock = AppLockService();
    lock.unlockAfterPinVerification();
    await lock.startSession(accessToken);
  }

  /// The signed-in email, read from the sign-in token. Null if it isn't there.
  static Future<String?> email() async {
    try {
      final token = await TokenService.getAuthToken();
      final parts = token?.split('.') ?? const [];
      if (parts.length != 3) return null;
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final email = payload is Map ? payload['email']?.toString() : null;
      return (email == null || email.isEmpty) ? null : email;
    } catch (_) {
      return null;
    }
  }

  /// Lock now (the lock screen covers the app).
  static void lock() => AppLockService().lockNow();

  static Future<void> signOut(NavigatorState navigator) async {
    await TokenService.clearTokens();
    HeartbeatService().clearToken();
    await BiometricService.disable();
    await DraftService.clear();
    await GoogleAuthService.signOut();
    await AppLockService().endSession();
    navigator.pushNamedAndRemoveUntil('/signin', (route) => false);
  }
}

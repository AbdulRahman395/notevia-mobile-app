import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// App lock, WhatsApp style.
///
/// When the app has been in the background for the user's chosen time, a lock
/// screen covers everything (what was on screen, including unsaved writing,
/// stays underneath). It's time based, not timer based: phones freeze timers in
/// the background and may kill the app, so we save the moment the app was hidden
/// and compare it with the clock when it comes back or starts again.
///
/// Preference values come from the server: 'off' | 'immediately' | '1 min' |
/// '5 min' | '10 min' | '30 min'.
class AppLockService extends ChangeNotifier {
  static final AppLockService _instance = AppLockService._internal();
  factory AppLockService() => _instance;
  AppLockService._internal();

  static const _prefKey = 'lock_preference';
  static const _hiddenAtKey = 'lock_hidden_at';

  /// Saved while the lock screen is up, so closing the app from the lock
  /// screen can't open it unlocked next time
  static const _lockedKey = 'lock_locked';

  static const options = ['immediately', '1 min', '5 min', '10 min', '30 min', 'off'];

  bool _sessionActive = false;
  bool _locked = false;
  String? _preference;
  int _excused = 0;
  DateTime? _hiddenAt;

  /// True while the lock screen should cover the app
  bool get isLocked => _sessionActive && _locked;

  /// A PIN-verified session is open
  bool get sessionActive => _sessionActive;
  String get preference => _preference ?? 'immediately';

  static Duration? delayFor(String pref) => switch (pref) {
    'immediately' => Duration.zero,
    '1 min' => const Duration(minutes: 1),
    '5 min' => const Duration(minutes: 5),
    '10 min' => const Duration(minutes: 10),
    '30 min' => const Duration(minutes: 30),
    _ => null, // off
  };

  static String labelFor(String pref) => switch (pref) {
    'immediately' => 'Immediately',
    '1 min' => 'After 1 minute',
    '5 min' => 'After 5 minutes',
    '10 min' => 'After 10 minutes',
    '30 min' => 'After 30 minutes',
    _ => 'Never',
  };

  /// Read the last known preference from the phone (works offline, instantly).
  Future<void> loadCachedPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _preference = prefs.getString(_prefKey) ?? _preference;
    } catch (_) {}
  }

  /// True when the app was closed while locked, or was killed while hidden
  /// and enough time has passed.
  Future<bool> shouldLockOnStartup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_lockedKey) == true) return true;
      final hiddenAt = prefs.getInt(_hiddenAtKey);
      await prefs.remove(_hiddenAtKey);
      final delay = delayFor(preference);
      if (hiddenAt == null || delay == null) return false;
      final elapsed = DateTime.now().millisecondsSinceEpoch - hiddenAt;
      return elapsed >= delay.inMilliseconds;
    } catch (_) {
      // Can't tell: lock rather than open a private journal
      return true;
    }
  }

  static Future<void> _saveLocked(bool locked) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (locked) {
        await prefs.setBool(_lockedKey, true);
      } else {
        // Unlocked with the PIN or phone: nothing left to lock for
        await prefs.remove(_lockedKey);
        await prefs.remove(_hiddenAtKey);
      }
    } catch (_) {}
  }

  /// Call after a PIN was verified or created. Loads the preference from the server.
  Future<void> startSession(String accessToken, {bool locked = false}) async {
    _sessionActive = true;
    _locked = locked;
    _hiddenAt = null;
    notifyListeners();
    await _saveLocked(locked);
    await refreshPreference(accessToken);
  }

  Future<void> refreshPreference(String token) async {
    try {
      final result = await ApiService.getLockPreferences(token);
      if (result['success'] == true && result['data'] != null) {
        await updateLockPreferences(
          (result['data']['preferences'] ?? 'immediately').toString(),
        );
      }
    } catch (_) {}
  }

  /// Sign out: no session, nothing to lock.
  Future<void> endSession() async {
    _sessionActive = false;
    _locked = false;
    _hiddenAt = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_hiddenAtKey);
      await prefs.remove(_lockedKey);
    } catch (_) {}
  }

  Future<void> updateLockPreferences(String preference) async {
    _preference = preference;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, preference);
    } catch (_) {}
  }

  void handleAppLifecycleChange(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _onHidden();
      case AppLifecycleState.resumed:
        _onResumed();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // Inactive = notification shade, app switcher peek, fingerprint dialog.
        // None of those should lock.
        break;
    }
  }

  void _onHidden() {
    if (!_sessionActive || _locked || _hiddenAt != null) return;
    if (_excused > 0) return;
    final delay = delayFor(preference);
    if (delay == null) return;
    _hiddenAt = DateTime.now();
    SharedPreferences.getInstance().then(
      (p) => p.setInt(_hiddenAtKey, _hiddenAt!.millisecondsSinceEpoch),
      onError: (_) => false,
    );
    // Lock right away so the app switcher shows the lock screen, not the journal
    if (delay == Duration.zero) lockNow(haptic: false);
  }

  void _onResumed() {
    final hiddenAt = _hiddenAt;
    _hiddenAt = null;
    SharedPreferences.getInstance().then((p) => p.remove(_hiddenAtKey), onError: (_) => false);
    if (hiddenAt == null || !_sessionActive || _locked) return;
    final delay = delayFor(preference);
    if (delay != null && DateTime.now().difference(hiddenAt) >= delay) {
      lockNow();
    }
  }

  /// Run a task that opens a system screen (photo picker, phone unlock prompt)
  /// without that trip to the background locking the app.
  Future<T> runExcused<T>(Future<T> Function() task) async {
    _excused++;
    try {
      return await task();
    } finally {
      // The "resumed" event can arrive just after the task completes
      Future.delayed(const Duration(milliseconds: 1500), () {
        _excused = (_excused - 1).clamp(0, 1 << 30);
      });
    }
  }

  void lockNow({bool haptic = true}) {
    if (!_sessionActive || _locked) return;
    _locked = true;
    notifyListeners();
    _saveLocked(true);
    if (haptic) HapticFeedback.mediumImpact();
  }

  /// Kept for older callers
  void forceLock() => lockNow();

  void unlockAfterPinVerification() {
    _sessionActive = true;
    if (_locked) {
      _locked = false;
      notifyListeners();
    }
    _saveLocked(false);
  }
}

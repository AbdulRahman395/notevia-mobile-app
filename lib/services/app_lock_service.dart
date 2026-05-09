import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';

enum AppLockState { unlocked, locked, pending }

class AppLockService extends ChangeNotifier {
  static final AppLockService _instance = AppLockService._internal();
  factory AppLockService() => _instance;
  AppLockService._internal();

  AppLockState _currentState = AppLockState.unlocked;
  Timer? _lockTimer;
  String? _currentToken;
  String? _lockPreference;
  DateTime? _appBackgroundedTime;

  AppLockState get currentState => _currentState;
  bool get isLocked => _currentState == AppLockState.locked;
  bool get isPending => _currentState == AppLockState.pending;

  // Initialize the service with a token
  Future<void> initialize(String token) async {
    _currentToken = token;
    await _loadLockPreferences();
  }

  // Load lock preferences from API
  Future<void> _loadLockPreferences() async {
    if (_currentToken == null) return;

    try {
      final result = await ApiService.getLockPreferences(_currentToken!);
      if (result['success'] == true && result['data'] != null) {
        _lockPreference = result['data']['preferences'] ?? 'immediately';
        print('Lock preference loaded: $_lockPreference');
      }
    } catch (e) {
      print('Error loading lock preferences: $e');
      _lockPreference = 'immediately'; // Default to immediately
    }
  }

  // Handle app lifecycle state changes
  void handleAppLifecycleChange(AppLifecycleState state) {
    print('App lifecycle state changed to: $state');

    switch (state) {
      case AppLifecycleState.paused:
        _onAppPaused();
        break;
      case AppLifecycleState.resumed:
        _onAppResumed();
        break;
      case AppLifecycleState.detached:
        _onAppDetached();
        break;
      case AppLifecycleState.inactive:
        _onAppInactive();
        break;
      case AppLifecycleState.hidden:
        _onAppHidden();
        break;
    }
  }

  void _onAppPaused() {
    print('App paused - starting lock timer');
    _appBackgroundedTime = DateTime.now();
    _startLockTimer();
  }

  void _onAppResumed() {
    print('App resumed - checking lock status');
    _cancelLockTimer();

    if (_currentState == AppLockState.pending) {
      _checkShouldLock();
    }
  }

  void _onAppDetached() {
    print('App detached - immediate lock');
    _lockApp();
  }

  void _onAppInactive() {
    print('App inactive - starting lock timer');
    _appBackgroundedTime = DateTime.now();
    _startLockTimer();
  }

  void _onAppHidden() {
    print('App hidden - starting lock timer');
    _appBackgroundedTime = DateTime.now();
    _startLockTimer();
  }

  // Start the lock timer based on user preferences
  void _startLockTimer() {
    _cancelLockTimer(); // Cancel any existing timer

    if (_lockPreference == 'off') {
      print('Lock is disabled');
      return;
    }

    if (_lockPreference == 'immediately') {
      print('Locking immediately');
      _lockApp();
      return;
    }

    final duration = _getLockDuration();
    if (duration != null) {
      print('Starting lock timer for ${duration.inSeconds} seconds');
      _currentState = AppLockState.pending;
      notifyListeners();

      _lockTimer = Timer(duration, () {
        print('Lock timer expired - locking app');
        _lockApp();
      });
    }
  }

  // Cancel the lock timer
  void _cancelLockTimer() {
    if (_lockTimer != null) {
      _lockTimer!.cancel();
      _lockTimer = null;
      print('Lock timer cancelled');
    }
  }

  // Get lock duration based on preference
  Duration? _getLockDuration() {
    switch (_lockPreference) {
      case '1 min':
        return const Duration(minutes: 1);
      case '5 min':
        return const Duration(minutes: 5);
      case '10 min':
        return const Duration(minutes: 10);
      case '30 min':
        return const Duration(minutes: 30);
      case 'immediately':
      case 'off':
      default:
        return null;
    }
  }

  // Check if app should be locked based on time spent in background
  void _checkShouldLock() {
    if (_appBackgroundedTime == null) return;

    final backgroundDuration = DateTime.now().difference(_appBackgroundedTime!);
    final requiredDuration = _getLockDuration();

    print('Background duration: ${backgroundDuration.inSeconds}s');

    if (requiredDuration != null && backgroundDuration >= requiredDuration) {
      print('Should lock - background time exceeded');
      _lockApp();
    } else {
      print('Should not lock - background time within limit');
      _unlockApp();
    }
  }

  // Lock the app
  void _lockApp() {
    if (_currentState != AppLockState.locked) {
      _currentState = AppLockState.locked;
      _cancelLockTimer();
      notifyListeners();
      print('App locked');

      // Trigger haptic feedback
      HapticFeedback.mediumImpact();
    }
  }

  // Unlock the app
  void _unlockApp() {
    if (_currentState != AppLockState.unlocked) {
      _currentState = AppLockState.unlocked;
      _cancelLockTimer();
      _appBackgroundedTime = null;
      notifyListeners();
      print('App unlocked');
    }
  }

  // Call this after successful PIN verification
  void unlockAfterPinVerification() {
    _unlockApp();
  }

  // Update lock preferences
  Future<void> updateLockPreferences(String preference) async {
    _lockPreference = preference;
    print('Lock preference updated to: $preference');

    // If app is currently in background, restart timer with new preference
    if (_appBackgroundedTime != null && _currentState == AppLockState.pending) {
      _startLockTimer();
    }
  }

  // Force lock immediately
  void forceLock() {
    _lockApp();
  }

  // Check if user has PIN setup
  Future<bool> hasUserSetupPin() async {
    if (_currentToken == null) return false;

    try {
      final result = await ApiService.hasPin(_currentToken!);
      return result['success'] == true &&
          result['data'] != null &&
          result['data']['hasPin'] == true;
    } catch (e) {
      print('Error checking PIN status: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _cancelLockTimer();
    super.dispose();
  }
}

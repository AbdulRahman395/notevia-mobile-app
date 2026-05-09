import 'dart:async';
import 'package:flutter/material.dart';
import 'api_service.dart';

class HeartbeatService extends ChangeNotifier {
  static final HeartbeatService _instance = HeartbeatService._internal();
  factory HeartbeatService() => _instance;
  HeartbeatService._internal();

  Timer? _heartbeatTimer;
  String? _currentToken;
  bool _isRunning = false;
  static const Duration _heartbeatInterval = Duration(seconds: 30);

  bool get isRunning => _isRunning;

  // Initialize the service with a token
  Future<void> initialize(String token) async {
    _currentToken = token;
    print('HeartbeatService initialized');
  }

  // Start heartbeat interval
  Future<void> startHeartbeat() async {
    if (_isRunning || _currentToken == null) {
      print('Heartbeat already running or no token available');
      return;
    }

    print('Starting heartbeat service');
    _isRunning = true;
    notifyListeners();

    // Send initial heartbeat immediately
    await _sendHeartbeatCall();

    // Set up periodic heartbeat
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _sendHeartbeatCall();
    });
  }

  // Stop heartbeat interval
  void stopHeartbeat() {
    if (!_isRunning) {
      print('Heartbeat service not running');
      return;
    }

    print('Stopping heartbeat service');
    _isRunning = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    notifyListeners();
  }

  // Send heartbeat API call
  Future<void> _sendHeartbeatCall() async {
    if (_currentToken == null || !_isRunning) {
      print('No token or heartbeat not running, skipping heartbeat');
      return;
    }

    try {
      final result = await ApiService.sendHeartbeat(_currentToken!);

      if (result['success'] == true) {
        print('Heartbeat sent successfully');
      } else {
        print('Heartbeat failed: ${result['message']}');

        // If authentication failed, stop heartbeat
        if (result['requires_auth_redirect'] == true) {
          print('Authentication expired, stopping heartbeat');
          stopHeartbeat();
        }
      }
    } catch (e) {
      print('Heartbeat error: $e');

      // Don't stop heartbeat on network errors, just log them
      // The service will retry on the next interval
    }
  }

  // Handle app lifecycle changes
  void handleAppLifecycleChange(AppLifecycleState state) {
    print('HeartbeatService: App lifecycle state changed to: $state');

    switch (state) {
      case AppLifecycleState.resumed:
        // App is visible and in foreground - start heartbeat
        print('App resumed, starting heartbeat');
        startHeartbeat();
        break;

      case AppLifecycleState.paused:
        // App is in background - stop heartbeat
        print('App paused, stopping heartbeat');
        stopHeartbeat();
        break;

      case AppLifecycleState.detached:
        // App is being destroyed - stop heartbeat
        print('App detached, stopping heartbeat');
        stopHeartbeat();
        break;

      case AppLifecycleState.inactive:
        // App is in transition state - stop heartbeat
        print('App inactive, stopping heartbeat');
        stopHeartbeat();
        break;

      case AppLifecycleState.hidden:
        // App is hidden - stop heartbeat
        print('App hidden, stopping heartbeat');
        stopHeartbeat();
        break;
    }
  }

  // Update token (called after login/refresh)
  void updateToken(String newToken) {
    _currentToken = newToken;
    print('HeartbeatService token updated');
  }

  // Clear token (called after logout)
  void clearToken() {
    _currentToken = null;
    stopHeartbeat();
    print('HeartbeatService token cleared');
  }

  @override
  void dispose() {
    stopHeartbeat();
    super.dispose();
  }
}

import 'package:shared_preferences/shared_preferences.dart';

class TokenService {
  static const String _authTokenKey = 'auth_token';
  static const String _accessTokenKey = 'access_token';

  // Store initial login token
  static Future<void> storeAuthToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_authTokenKey, token);
      print('Auth token stored successfully');
    } catch (e) {
      print('Error storing auth token: $e');
    }
  }

  // Store access token after PIN verification/creation
  static Future<void> storeAccessToken(String accessToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accessTokenKey, accessToken);
      print('Access token stored successfully');
    } catch (e) {
      print('Error storing access token: $e');
    }
  }

  // Get auth token
  static Future<String?> getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_authTokenKey);
    } catch (e) {
      print('Error getting auth token: $e');
      return null;
    }
  }

  // Get access token
  static Future<String?> getAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_accessTokenKey);
    } catch (e) {
      print('Error getting access token: $e');
      return null;
    }
  }

  // Check if user has auth token (should go to PIN verification)
  static Future<bool> hasAuthToken() async {
    final token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }

  // Check if user has access token (should go to home)
  static Future<bool> hasAccessToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // Clear all tokens (logout)
  static Future<void> clearTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_authTokenKey);
      await prefs.remove(_accessTokenKey);
      print('Tokens cleared successfully');
    } catch (e) {
      print('Error clearing tokens: $e');
    }
  }

  // Get current token for API calls
  static Future<String> getCurrentToken() async {
    // Try access token first, then auth token
    final accessToken = await getAccessToken();
    if (accessToken != null && accessToken.isNotEmpty) {
      return accessToken;
    }
    final authToken = await getAuthToken();
    return authToken ?? '';
  }
}

import 'package:google_sign_in/google_sign_in.dart';
import '../config.dart';
import 'api_service.dart';
import 'app_lock_service.dart';
import 'token_service.dart';

/// The result of "Continue with Google".
class GoogleAuthResult {
  const GoogleAuthResult._({this.token, this.error});

  /// Login token (the same kind /auth/login returns), then the PIN screen
  final String? token;
  final String? error;

  bool get cancelled => token == null && error == null;
}

/// Continue with Google on Android / iOS: the phone's Google account picker
/// gives an ID token, and the backend swaps it for a Notevia login.
class GoogleAuthService {
  static Future<void>? _init;

  static Future<void> _ready() => _init ??= GoogleSignIn.instance.initialize(
    serverClientId: AppConfig.googleWebClientId,
  );

  static Future<GoogleAuthResult> signIn() async {
    final String? idToken;
    try {
      await _ready();
      // The account sheet can send the app to the background; don't lock for it
      final account = await AppLockService().runExcused(
        () => GoogleSignIn.instance.authenticate(scopeHint: const ['email']),
      );
      idToken = account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return const GoogleAuthResult._();
      }
      if (e.code == GoogleSignInExceptionCode.clientConfigurationError ||
          e.code == GoogleSignInExceptionCode.providerConfigurationError) {
        return const GoogleAuthResult._(
          error: 'Google sign-in isn’t set up for this app yet. Use your email and password.',
        );
      }
      return const GoogleAuthResult._(error: 'Google sign-in didn’t work. Try again.');
    } catch (_) {
      _init = null; // try initialising again next time
      return const GoogleAuthResult._(error: 'Google sign-in isn’t available on this phone.');
    }

    if (idToken == null || idToken.isEmpty) {
      return const GoogleAuthResult._(error: 'Google didn’t confirm your account. Try again.');
    }

    final result = await ApiService.googleLogin(idToken);
    if (result['success'] != true) {
      // Let the person pick a different account next time
      await signOut();
      return GoogleAuthResult._(error: result['message'].toString());
    }
    final data = result['data'];
    final token = (data is Map ? (data['token'] ?? data['accessToken']) : null)?.toString() ?? '';
    if (token.isEmpty) return const GoogleAuthResult._(error: 'Google sign-in failed. Try again.');
    await TokenService.storeAuthToken(token);
    return GoogleAuthResult._(token: token);
  }

  /// Forget the Google account on this phone, so the picker shows next time.
  static Future<void> signOut() async {
    try {
      await _ready();
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}

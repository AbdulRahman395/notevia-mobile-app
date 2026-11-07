/// App-wide settings.
class AppConfig {
  /// The Web OAuth client ID from Google Cloud (the same one the website and
  /// backend use). Android asks Google for an ID token made for this ID, which
  /// is what the backend's POST /auth/google checks.
  /// Override at build time with --dart-define=GOOGLE_WEB_CLIENT_ID=...
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '374280487920-9suju880c4qs3nqh5c02fend59mv7ce1.apps.googleusercontent.com',
  );
}

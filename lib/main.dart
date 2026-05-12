import 'package:flutter/material.dart';
import 'services/theme_service.dart';
import 'services/app_lock_service.dart';
import 'services/heartbeat_service.dart';
import 'services/token_service.dart';
import 'pages/splash_screen.dart';
import 'pages/signin_page.dart';
import 'pages/signup_page.dart';
import 'pages/verification_page.dart';
import 'pages/create_pin_page.dart';
import 'pages/pin_verification_page.dart';
import 'pages/home_page.dart';
import 'pages/journal_detail_page.dart';
import 'pages/journal_entry_page.dart';
import 'pages/app_lock_preferences_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final ThemeService _themeService = ThemeService();
  final AppLockService _appLockService = AppLockService();
  final HeartbeatService _heartbeatService = HeartbeatService();
  String? _currentToken;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _themeService.loadTheme();
    _initializeServices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appLockService.dispose();
    _heartbeatService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLockService.handleAppLifecycleChange(state);
    _heartbeatService.handleAppLifecycleChange(state);
  }

  Future<void> _initializeServices() async {
    _currentToken = await TokenService.getAccessToken();
    if (_currentToken != null) {
      await _appLockService.initialize(_currentToken!);
      await _heartbeatService.initialize(_currentToken!);

      // Start heartbeat if app is in foreground
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _heartbeatService.startHeartbeat();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _themeService,
        _appLockService,
        _heartbeatService,
      ]),
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Notevia',
          theme: _themeService.lightTheme,
          darkTheme: _themeService.darkTheme,
          themeMode: _themeService.themeMode,
          initialRoute: '/',
          onGenerateRoute: (settings) {
            // Check if app is locked and redirect to PIN verification
            if (_appLockService.isLocked && _currentToken != null) {
              // Allow certain routes even when locked
              if (settings.name != '/pin-verification' &&
                  settings.name != '/create-pin' &&
                  settings.name != '/signin' &&
                  settings.name != '/signup' &&
                  settings.name != '/') {
                return MaterialPageRoute(
                  builder: (context) =>
                      PinVerificationPage(token: _currentToken!),
                );
              }
            }

            switch (settings.name) {
              case '/':
                return MaterialPageRoute(
                  builder: (context) => const SplashScreen(),
                );
              case '/signin':
                return MaterialPageRoute(
                  builder: (context) => const SigninPage(),
                );
              case '/signup':
                return MaterialPageRoute(
                  builder: (context) => const SignupPage(),
                );
              case '/verification':
                final email = settings.arguments as String?;
                return MaterialPageRoute(
                  builder: (context) => VerificationPage(email: email ?? ''),
                );
              case '/create-pin':
                final token = settings.arguments as String? ?? _currentToken;
                return MaterialPageRoute(
                  builder: (context) => CreatePinPage(token: token ?? ''),
                );
              case '/pin-verification':
                final token = settings.arguments as String? ?? _currentToken;
                return MaterialPageRoute(
                  builder: (context) => PinVerificationPage(token: token ?? ''),
                );
              case '/home':
                return MaterialPageRoute(
                  builder: (context) => const HomePage(),
                );
              case '/journal-detail':
                final journalId = settings.arguments as int?;
                return MaterialPageRoute(
                  builder: (context) =>
                      JournalDetailPage(journalId: journalId ?? 0),
                );
              case '/journal-entry':
                final journalData = settings.arguments as Map<String, dynamic>?;
                return MaterialPageRoute(
                  builder: (context) =>
                      JournalEntryPage(journalData: journalData),
                );
              case '/app-lock-preferences':
                return MaterialPageRoute(
                  builder: (context) => const AppLockPreferencesPage(),
                );
              default:
                return MaterialPageRoute(
                  builder: (context) => const SigninPage(),
                );
            }
          },
        );
      },
    );
  }
}

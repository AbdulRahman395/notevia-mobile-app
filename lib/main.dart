import 'package:flutter/material.dart';
import 'app_navigator.dart';
import 'services/theme_service.dart';
import 'services/app_lock_service.dart';
import 'services/draft_service.dart';
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
import 'pages/change_pin_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themes = ThemeService();
  final lock = AppLockService();
  await Future.wait([themes.loadTheme(), lock.loadCachedPreference()]);

  // Restore a signed-in session, locked if the app was away long enough
  final accessToken = await TokenService.getAccessToken();
  if (accessToken != null && accessToken.isNotEmpty) {
    final startLocked = await lock.shouldLockOnStartup();
    lock.startSession(accessToken, locked: startLocked);
    HeartbeatService().initialize(accessToken);
  }

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_appLockService.sessionActive &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _heartbeatService.startHeartbeat();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLockService.handleAppLifecycleChange(state);
    _heartbeatService.handleAppLifecycleChange(state);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _themeService,
      builder: (context, _) => MaterialApp(
        navigatorKey: appNavigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'Notevia',
        theme: _themeService.lightTheme,
        darkTheme: _themeService.darkTheme,
        themeMode: _themeService.themeMode,
        initialRoute: '/',
        // The lock screen sits above every page, so locking never loses what's on screen
        builder: (context, child) => ListenableBuilder(
          listenable: _appLockService,
          builder: (context, _) => Stack(
            children: [
              ExcludeFocus(
                excluding: _appLockService.isLocked,
                child: ExcludeSemantics(
                  excluding: _appLockService.isLocked,
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
              // Its own Overlay: the lock screen sits above the Navigator, and
              // text fields (Forgot PIN) need one for the cursor and handles
              if (_appLockService.isLocked)
                Positioned.fill(
                  child: Overlay(
                    initialEntries: [OverlayEntry(builder: (_) => const LockScreen(overlay: true))],
                  ),
                ),
            ],
          ),
        ),
        onGenerateRoute: (settings) {
          final Widget page = switch (settings.name) {
            '/' => const SplashScreen(),
            '/signin' => const SigninPage(),
            '/signup' => const SignupPage(),
            '/verification' => VerificationPage(email: settings.arguments as String? ?? ''),
            '/create-pin' => CreatePinPage(token: settings.arguments as String? ?? ''),
            '/pin-verification' => PinVerificationPage(token: settings.arguments as String? ?? ''),
            '/home' => HomePage(draft: settings.arguments as JournalDraft?),
            '/journal-detail' => JournalDetailPage(journalId: settings.arguments as int? ?? 0),
            '/journal-entry' => switch (settings.arguments) {
              final JournalDraft d => JournalEntryPage(journalData: d.journal, draft: d),
              final args => JournalEntryPage(journalData: args as Map<String, dynamic>?),
            },
            '/app-lock-preferences' => const AppLockPreferencesPage(),
            '/change-pin' => const ChangePinPage(),
            _ => const SigninPage(),
          };
          return MaterialPageRoute(builder: (_) => page, settings: settings);
        },
      ),
    );
  }
}

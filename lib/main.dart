import 'package:flutter/material.dart';
import 'services/theme_service.dart';
import 'pages/splash_screen.dart';
import 'pages/signin_page.dart';
import 'pages/signup_page.dart';
import 'pages/verification_page.dart';
import 'pages/create_pin_page.dart';
import 'pages/pin_verification_page.dart';
import 'pages/home_page.dart';
import 'pages/journal_detail_page.dart';
import 'pages/journal_entry_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeService _themeService = ThemeService();

  @override
  void initState() {
    super.initState();
    _themeService.loadTheme();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeService,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Notevia',
          theme: _themeService.lightTheme,
          darkTheme: _themeService.darkTheme,
          themeMode: _themeService.themeMode,
          initialRoute: '/',
          onGenerateRoute: (settings) {
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
                final token = settings.arguments as String?;
                return MaterialPageRoute(
                  builder: (context) => CreatePinPage(token: token ?? ''),
                );
              case '/pin-verification':
                final token = settings.arguments as String?;
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
                return MaterialPageRoute(
                  builder: (context) => const JournalEntryPage(),
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

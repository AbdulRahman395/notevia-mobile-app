import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/token_service.dart';
import 'signin_page.dart';
import 'pin_verification_page.dart';
import 'home_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Entrance animation: staggers the logo, title, slogan, and loader in.
  late AnimationController _entranceController;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _sloganFade;
  late Animation<double> _loaderFade;

  // Slow ambient "breathing" glow behind the logo card, loops forever.
  late AnimationController _glowController;
  late Animation<double> _glowScale;

  // Three-dot loading indicator, loops forever.
  late AnimationController _dotsController;
  static const List<Interval> _dotIntervals = [
    Interval(0.0, 0.6, curve: Curves.linear),
    Interval(0.15, 0.75, curve: Curves.linear),
    Interval(0.3, 0.9, curve: Curves.linear),
  ];

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1300),
      vsync: this,
    );

    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.35, 0.7, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.35, 0.7, curve: Curves.easeOutCubic),
          ),
        );
    _sloganFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.55, 0.85, curve: Curves.easeOut),
      ),
    );
    _loaderFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.75, 1.0, curve: Curves.easeOut),
      ),
    );

    _entranceController.forward();

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    )..repeat(reverse: true);
    _glowScale = Tween<double>(begin: 0.92, end: 1.12).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    )..repeat();

    // Check tokens and navigate after 3 seconds
    Future.delayed(const Duration(seconds: 3), () async {
      if (mounted) {
        try {
          final hasAccessToken = await TokenService.hasAccessToken();
          final hasAuthToken = await TokenService.hasAuthToken();

          if (hasAccessToken) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          } else if (hasAuthToken) {
            final token = await TokenService.getAuthToken();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => PinVerificationPage(token: token ?? ''),
              ),
            );
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const SigninPage()),
            );
          }
        } catch (e) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const SigninPage()),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _glowController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  Widget _buildBackgroundDecoration({
    required double size,
    required Alignment alignment,
    required double opacity,
  }) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _dotsController,
      builder: (context, child) {
        final t = _dotIntervals[index].transform(_dotsController.value);
        final bump = math.sin(t * math.pi).clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Opacity(
            opacity: 0.5 + 0.5 * bump,
            child: Transform.scale(
              scale: 0.7 + 0.5 * bump,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient backdrop, consistent with the accent used across the app
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue[400]!, Colors.blue[700]!],
              ),
            ),
          ),

          // Soft decorative circles for depth
          _buildBackgroundDecoration(
            size: 260,
            alignment: const Alignment(-1.3, -1.1),
            opacity: 0.08,
          ),
          _buildBackgroundDecoration(
            size: 340,
            alignment: const Alignment(1.3, 1.2),
            opacity: 0.06,
          ),
          _buildBackgroundDecoration(
            size: 140,
            alignment: const Alignment(1.1, -0.9),
            opacity: 0.07,
          ),

          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo with ambient glow + entrance scale/fade
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _entranceController,
                      _glowController,
                    ]),
                    builder: (context, child) {
                      return Opacity(
                        opacity: _logoFade.value,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Glow
                              Transform.scale(
                                scale: _glowScale.value,
                                child: Container(
                                  width: 130,
                                  height: 130,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                              ),
                              // Logo card
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(26),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.15,
                                      ),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.menu_book_rounded,
                                  size: 48,
                                  color: Colors.blue[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 36),

                  // App Title
                  FadeTransition(
                    opacity: _titleFade,
                    child: SlideTransition(
                      position: _titleSlide,
                      child: const Text(
                        'Notevia',
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Slogan
                  FadeTransition(
                    opacity: _sloganFade,
                    child: Text(
                      'Only you and your thoughts',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: 0.85),
                        fontStyle: FontStyle.italic,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 64),

                  // Loading indicator — three softly pulsing dots
                  FadeTransition(
                    opacity: _loaderFade,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (index) => _buildDot(index)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

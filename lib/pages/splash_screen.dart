import 'package:flutter/material.dart';
import '../services/draft_service.dart';
import '../services/token_service.dart';
import '../ui/nv.dart';

/// Matches the native launch screen (dark canvas, the ›_ mark), then routes.
/// No artificial wait: it leaves as soon as it knows where to go.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    String target = '/signin';
    Object? args;
    try {
      if (await TokenService.hasAccessToken()) {
        target = '/home';
        args = await DraftService.load();
      } else if (await TokenService.hasAuthToken()) {
        target = '/pin-verification';
        args = await TokenService.getAuthToken();
      }
    } catch (_) {}
    // A short beat so the mark doesn't flash on fast phones
    await Future.delayed(const Duration(milliseconds: 350));
    if (mounted) Navigator.of(context).pushReplacementNamed(target, arguments: args);
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: NvBrand.canvas,
    // 108dp × 0.62: the same size as the glyph on the native launch screen
    body: Center(child: NvGlyph(size: 67)),
  );
}

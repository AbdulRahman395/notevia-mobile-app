import 'package:flutter/material.dart';
import '../services/google_auth_service.dart';
import '../theme/tokens.dart';
import 'buttons.dart';

/// "Continue with Google" and the divider under it, for the sign-in and
/// sign-up screens. On success it goes to the PIN screen like an email login
/// (new Google accounts are sent on to create a PIN from there).
class NvGoogleSignIn extends StatefulWidget {
  const NvGoogleSignIn({super.key, required this.onError, required this.dividerLabel, this.enabled = true});

  final ValueChanged<String?> onError;
  final String dividerLabel;
  final bool enabled;

  @override
  State<NvGoogleSignIn> createState() => _NvGoogleSignInState();
}

class _NvGoogleSignInState extends State<NvGoogleSignIn> {
  bool _loading = false;

  Future<void> _go() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    widget.onError(null);
    setState(() => _loading = true);
    final result = await GoogleAuthService.signIn();
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.token != null) {
      Navigator.of(context).pushReplacementNamed('/pin-verification', arguments: result.token);
    } else if (result.error != null) {
      widget.onError(result.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nv;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NvButton.secondary(
          label: 'Continue with Google',
          large: true,
          expand: true,
          loading: _loading,
          leading: Image.asset('assets/brand/google-g.png', width: 18, height: 18, filterQuality: FilterQuality.medium),
          onPressed: widget.enabled ? _go : null,
        ),
        const SizedBox(height: NvSpace.lg),
        Row(
          children: [
            Expanded(child: Divider(color: c.lineMuted, height: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: NvSpace.sm),
              child: Text(widget.dividerLabel, style: NvText.meta.copyWith(color: c.muted)),
            ),
            Expanded(child: Divider(color: c.lineMuted, height: 1)),
          ],
        ),
        const SizedBox(height: NvSpace.lg),
      ],
    );
  }
}

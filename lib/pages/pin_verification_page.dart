import 'package:flutter/material.dart';
import '../app_navigator.dart';
import '../services/api_service.dart';
import '../services/biometric_service.dart';
import '../services/draft_service.dart';
import '../services/session.dart';
import '../ui/nv.dart';
import 'change_pin_page.dart';

/// "Enter PIN" after signing in. The same screen covers the app when it locks.
class PinVerificationPage extends StatelessWidget {
  final String token;

  const PinVerificationPage({super.key, required this.token});

  @override
  Widget build(BuildContext context) => LockScreen(authToken: token);
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, this.authToken, this.overlay = false});

  /// Login token, used on the route to check the account has a PIN
  final String? authToken;

  /// True when shown over the app (no Navigator above it)
  final bool overlay;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pad = GlobalKey<NvPinPadState>();
  PhoneUnlockInfo _phone = PhoneUnlockInfo.none;
  bool _phoneEnabled = false;
  bool _checking = true;
  bool _forgot = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (!widget.overlay && widget.authToken != null && widget.authToken!.isNotEmpty) {
      final result = await ApiService.hasPin(widget.authToken!);
      if (!mounted) return;
      if (result['requires_login_redirect'] == true) {
        appNavigatorKey.currentState?.pushNamedAndRemoveUntil('/signin', (r) => false);
        return;
      }
      final data = result['data'];
      if (result['success'] == true && data is Map && data['hasPin'] == false) {
        appNavigatorKey.currentState?.pushReplacementNamed('/create-pin', arguments: widget.authToken);
        return;
      }
    }
    final enabled = await BiometricService.isEnabled();
    final info = enabled ? await BiometricService.info() : PhoneUnlockInfo.none;
    if (!mounted) return;
    setState(() {
      _phoneEnabled = enabled && info.available;
      _phone = info;
      _checking = false;
    });
    if (_phoneEnabled) _usePhone();
  }

  Future<String?> _submit(String pin) async {
    final error = await Session.verifyPin(pin);
    if (error == null) {
      // The PIN changed since phone unlock was set up: save the new one
      // (one fingerprint check) so phone unlock keeps working.
      if (await BiometricService.isStale()) await BiometricService.resync(pin);
      _opened();
    }
    return error;
  }

  Future<void> _usePhone() async {
    final error = await Session.unlockWithPhone();
    if (!mounted) return;
    if (error == null) {
      _opened();
    } else if (error.isNotEmpty) {
      setState(() => _phoneEnabled = false);
      _pad.currentState?.reset(error: error);
    }
  }

  void _opened() {
    // As an overlay the lock simply lifts; as a route, go to the journal
    final nav = appNavigatorKey.currentState;
    if (!widget.overlay && nav != null) DraftService.openHome(nav);
  }

  Future<void> _signOut() async {
    final nav = appNavigatorKey.currentState;
    if (nav != null) await Session.signOut(nav);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nv;
    if (_forgot) {
      return ForgotPinView(
        onCancel: () => setState(() => _forgot = false),
        onDone: () {
          setState(() => _forgot = false);
          _opened();
        },
      );
    }
    return Material(
      color: c.bg,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: NvSpace.lg),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      const SizedBox(height: NvSpace.lg),
                      const NvMark(size: 44),
                      const SizedBox(height: NvSpace.md),
                      Text(
                        widget.overlay ? 'Notevia is locked' : 'Enter your PIN',
                        style: NvText.title.copyWith(color: c.fg),
                      ),
                      const SizedBox(height: NvSpace.xxs),
                      Text(
                        _phoneEnabled
                            ? 'Use your ${_phone.label} or your PIN'
                            : 'Enter your 4-digit Notevia PIN',
                        style: NvText.small.copyWith(color: c.muted),
                      ),
                      const SizedBox(height: NvSpace.xl),
                      NvPinPad(
                        key: _pad,
                        enabled: !_checking || widget.overlay,
                        onSubmit: _submit,
                        onBiometric: _phoneEnabled ? _usePhone : null,
                        biometricIcon: _phone.icon,
                        biometricLabel: 'Unlock with ${_phone.label}',
                      ),
                      const Spacer(flex: 3),
                      TextButton(
                        onPressed: () => setState(() => _forgot = true),
                        child: const Text('Forgot PIN?'),
                      ),
                      TextButton(
                        onPressed: _signOut,
                        style: TextButton.styleFrom(foregroundColor: c.muted),
                        child: const Text('Sign out'),
                      ),
                      const SizedBox(height: NvSpace.xs),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/biometric_service.dart';
import '../services/session.dart';
import '../ui/nv.dart';

enum _Step { create, confirm, phoneUnlock }

/// New PIN: type it, type it again, then optionally turn on phone unlock.
class CreatePinPage extends StatefulWidget {
  final String token;

  const CreatePinPage({super.key, required this.token});

  @override
  State<CreatePinPage> createState() => _CreatePinPageState();
}

class _CreatePinPageState extends State<CreatePinPage> {
  final _pad = GlobalKey<NvPinPadState>();
  _Step _step = _Step.create;
  String _first = '';
  PhoneUnlockInfo _phone = PhoneUnlockInfo.none;
  bool _enabling = false;

  @override
  void initState() {
    super.initState();
    BiometricService.info().then((i) {
      if (mounted) setState(() => _phone = i);
    });
  }

  Future<String?> _submit(String pin) async {
    if (_step == _Step.create) {
      _first = pin;
      setState(() => _step = _Step.confirm);
      _pad.currentState?.reset();
      return null;
    }
    if (pin != _first) {
      setState(() => _step = _Step.create);
      return 'PINs didn’t match. Start again.';
    }
    try {
      final result = await ApiService.createPIN(widget.token, pin);
      if (result['success'] != true) {
        setState(() => _step = _Step.create);
        return (result['message'] ?? 'Couldn’t save your PIN').toString();
      }
      final data = result['data'] ?? {};
      // A new PIN makes any PIN saved for phone unlock out of date
      await BiometricService.disable();
      await Session.opened((data['accessToken'] ?? data['token'] ?? '').toString());
      if (!mounted) return null;
      if (_phone.available) {
        setState(() => _step = _Step.phoneUnlock);
      } else {
        _goHome();
      }
      return null;
    } catch (_) {
      setState(() => _step = _Step.create);
      return 'Couldn’t reach Notevia. Check your connection.';
    }
  }

  Future<void> _turnOnPhoneUnlock() async {
    setState(() => _enabling = true);
    try {
      await BiometricService.enable(_first);
    } catch (_) {
      // Not fatal: it can be turned on later in Settings
    }
    if (mounted) _goHome();
  }

  void _goHome() => Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);

  @override
  Widget build(BuildContext context) {
    final c = context.nv;

    if (_step == _Step.phoneUnlock) {
      return NvAuthLayout(
        header: Icon(_phone.icon, size: 40, color: c.accent),
        title: 'Unlock with your ${_phone.label}?',
        subtitle: 'Open Notevia the way you unlock your phone, like WhatsApp. Your PIN still works.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NvButton(
              label: 'Turn on',
              large: true,
              expand: true,
              loading: _enabling,
              onPressed: _turnOnPhoneUnlock,
            ),
            const SizedBox(height: NvSpace.xs),
            NvButton.secondary(label: 'Not now', large: true, expand: true, onPressed: _enabling ? null : _goHome),
          ],
        ),
      );
    }

    final confirming = _step == _Step.confirm;
    return Scaffold(
      appBar: AppBar(
        leading: confirming
            ? BackButton(onPressed: () {
                setState(() => _step = _Step.create);
                _pad.currentState?.reset();
              })
            : null,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const Spacer(),
                    const NvMark(size: 44),
                    const SizedBox(height: NvSpace.md),
                    Text(
                      confirming ? 'Confirm your PIN' : 'Create a PIN',
                      style: NvText.title.copyWith(color: c.fg),
                    ),
                    const SizedBox(height: NvSpace.xxs),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: NvSpace.lg),
                      child: Text(
                        confirming
                            ? 'Enter the same 4 digits again'
                            : 'You’ll use it to open Notevia on this phone',
                        textAlign: TextAlign.center,
                        style: NvText.small.copyWith(color: c.muted),
                      ),
                    ),
                    const SizedBox(height: NvSpace.xl),
                    NvPinPad(key: _pad, onSubmit: _submit),
                    const Spacer(flex: 2),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

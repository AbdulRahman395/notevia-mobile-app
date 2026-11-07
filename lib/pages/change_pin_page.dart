import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/biometric_service.dart';
import '../services/session.dart';
import '../services/toaster_service.dart';
import '../services/token_service.dart';
import '../ui/nv.dart';

/// A PIN step: the mark, a heading, one line, the keypad and an optional link.
class PinStep extends StatelessWidget {
  const PinStep({super.key, required this.title, required this.subtitle, required this.pad, this.leading, this.footer});

  final String title;
  final String subtitle;
  final Widget pad;
  final Widget? leading;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final c = context.nv;
    return Scaffold(
      appBar: AppBar(leading: leading, automaticallyImplyLeading: false),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: NvSpace.lg),
                  child: Column(
                    children: [
                      const Spacer(),
                      const NvMark(size: 44),
                      const SizedBox(height: NvSpace.md),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: NvText.title.copyWith(color: c.fg),
                      ),
                      const SizedBox(height: NvSpace.xxs),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: NvText.small.copyWith(color: c.muted),
                      ),
                      const SizedBox(height: NvSpace.xl),
                      pad,
                      const Spacer(flex: 2),
                      if (footer != null) ...[footer!, const SizedBox(height: NvSpace.xs)],
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

enum _ChangeStep { current, next, confirm }

/// Settings → Change PIN: current PIN, new PIN, the new PIN again.
class ChangePinPage extends StatefulWidget {
  const ChangePinPage({super.key});

  @override
  State<ChangePinPage> createState() => _ChangePinPageState();
}

class _ChangePinPageState extends State<ChangePinPage> {
  final _pad = GlobalKey<NvPinPadState>();
  _ChangeStep _step = _ChangeStep.current;
  String _current = '';
  String _next = '';

  void _go(_ChangeStep step, {String? error}) {
    setState(() => _step = step);
    _pad.currentState?.reset(error: error);
  }

  Future<String?> _submit(String pin) async {
    switch (_step) {
      case _ChangeStep.current:
        _current = pin;
        _go(_ChangeStep.next);
        return null;
      case _ChangeStep.next:
        if (pin == _current) return 'Choose a PIN different from your current one';
        _next = pin;
        _go(_ChangeStep.confirm);
        return null;
      case _ChangeStep.confirm:
        if (pin != _next) {
          _go(_ChangeStep.next, error: 'PINs didn’t match. Enter the new PIN again.');
          return null;
        }
        final token = await TokenService.getAuthToken() ?? '';
        final result = await ApiService.changePin(token, _current, _next);
        if (!mounted) return null;
        if (result['success'] == true) {
          await BiometricService.replacePin(_next);
          if (!mounted) return null;
          ToasterService.showSuccess(context, 'PIN changed');
          Navigator.of(context).pop();
          return null;
        }
        final message = (result['message'] ?? 'Couldn’t change your PIN').toString();
        if (message.toLowerCase().contains('current pin')) {
          _go(_ChangeStep.current, error: 'Your current PIN is incorrect');
        } else {
          _go(_ChangeStep.current, error: message);
        }
        return null;
    }
  }

  void _forgot() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ForgotPinView(
          onCancel: () => Navigator.of(context).pop(),
          onDone: () {
            ToasterService.showSuccess(context, 'PIN reset');
            Navigator.of(context)
              ..pop()
              ..pop();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (_step) {
      _ChangeStep.current => ('Enter your current PIN', 'To change it, first confirm the PIN you use now'),
      _ChangeStep.next => ('Choose a new PIN', 'Pick 4 digits you’ll remember'),
      _ChangeStep.confirm => ('Confirm your new PIN', 'Enter the same 4 digits again'),
    };
    return PopScope(
      canPop: _step == _ChangeStep.current,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(_step == _ChangeStep.confirm ? _ChangeStep.next : _ChangeStep.current);
      },
      child: PinStep(
        leading: BackButton(onPressed: () => Navigator.of(context).maybePop()),
        title: title,
        subtitle: subtitle,
        pad: NvPinPad(key: _pad, onSubmit: _submit),
        footer: _step == _ChangeStep.current ? TextButton(onPressed: _forgot, child: const Text('Forgot PIN?')) : null,
      ),
    );
  }
}

enum _ForgotStep { send, code, next, confirm }

/// Forgot PIN: email a code, enter it, choose a new PIN. Used as its own page
/// and inside the lock screen, so it needs no Navigator.
class ForgotPinView extends StatefulWidget {
  const ForgotPinView({super.key, required this.onDone, required this.onCancel});

  /// The PIN was reset and accepted; Notevia is unlocked
  final VoidCallback onDone;
  final VoidCallback onCancel;

  @override
  State<ForgotPinView> createState() => _ForgotPinViewState();
}

class _ForgotPinViewState extends State<ForgotPinView> {
  final _pad = GlobalKey<NvPinPadState>();
  final _code = TextEditingController();
  final _emailField = TextEditingController();
  _ForgotStep _step = _ForgotStep.send;
  String? _email;
  bool _loadingEmail = true;
  bool _sending = false;
  String? _error;
  String? _notice;
  String _next = '';

  @override
  void initState() {
    super.initState();
    Session.email().then((e) {
      if (mounted) {
        setState(() {
          _email = e;
          _loadingEmail = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _code.dispose();
    _emailField.dispose();
    super.dispose();
  }

  String get _address => (_email ?? _emailField.text).trim();

  Future<void> _send({bool again = false}) async {
    if (_sending) return;
    final email = _address;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(email)) {
      setState(() => _error = 'Enter the email you signed in with');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
      _notice = null;
    });
    final token = await TokenService.getAuthToken() ?? '';
    final result = await ApiService.forgetPin(token, email);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (result['success'] == true) {
        _step = _ForgotStep.code;
        _code.clear();
        _notice = again ? 'We sent a new code.' : null;
      } else {
        _error = (result['message'] ?? 'Couldn’t send the code').toString();
      }
    });
  }

  void _codeEntered() {
    if (_code.text.length != 6) {
      setState(() => _error = 'Enter all 6 digits');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _notice = null;
      _step = _ForgotStep.next;
    });
  }

  void _toPinStep(_ForgotStep step, {String? error}) {
    setState(() => _step = step);
    _pad.currentState?.reset(error: error);
  }

  Future<String?> _submitPin(String pin) async {
    if (_step == _ForgotStep.next) {
      _next = pin;
      _toPinStep(_ForgotStep.confirm);
      return null;
    }
    if (pin != _next) {
      _toPinStep(_ForgotStep.next, error: 'PINs didn’t match. Enter the new PIN again.');
      return null;
    }
    final token = await TokenService.getAuthToken() ?? '';
    final result = await ApiService.resetPin(token, _address, _code.text, _next);
    if (!mounted) return null;
    if (result['success'] != true) {
      final message = (result['message'] ?? 'Couldn’t reset your PIN').toString();
      setState(() {
        _step = _ForgotStep.code;
        _error = message;
      });
      return null;
    }
    // Open Notevia with the new PIN, and keep phone unlock working with it
    await BiometricService.replacePin(_next);
    final error = await Session.verifyPin(_next);
    if (!mounted) return null;
    if (error != null) {
      widget.onCancel();
      return null;
    }
    widget.onDone();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nv;
    final back = IconButton(
      tooltip: 'Back',
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        switch (_step) {
          case _ForgotStep.send:
            widget.onCancel();
          case _ForgotStep.code:
            setState(() {
              _step = _ForgotStep.send;
              _error = null;
              _notice = null;
            });
          case _ForgotStep.next:
            setState(() => _step = _ForgotStep.code);
          case _ForgotStep.confirm:
            _toPinStep(_ForgotStep.next);
        }
      },
    );

    if (_step == _ForgotStep.next || _step == _ForgotStep.confirm) {
      final confirming = _step == _ForgotStep.confirm;
      return PinStep(
        leading: back,
        title: confirming ? 'Confirm your new PIN' : 'Choose a new PIN',
        subtitle: confirming ? 'Enter the same 4 digits again' : 'Pick 4 digits you’ll remember',
        pad: NvPinPad(key: _pad, onSubmit: _submitPin),
      );
    }

    final alert = [
      if (_error != null) ...[NvAlert(_error!), const SizedBox(height: NvSpace.md)],
      if (_notice != null) ...[
        Text(_notice!, style: NvText.small.copyWith(color: c.success)),
        const SizedBox(height: NvSpace.md),
      ],
    ];

    if (_step == _ForgotStep.code) {
      return NvAuthLayout(
        leading: back,
        title: 'Check your email',
        subtitle: 'We sent a 6-digit code to $_address.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...alert,
            NvCodeField(controller: _code, onCompleted: (_) => _codeEntered()),
            const SizedBox(height: NvSpace.lg),
            NvButton(label: 'Continue', large: true, expand: true, onPressed: _codeEntered),
            const SizedBox(height: NvSpace.sm),
            Row(
              children: [
                Expanded(
                  child: Text('Can’t find it? Check your spam folder.', style: NvText.meta.copyWith(color: c.muted)),
                ),
                TextButton(
                  onPressed: _sending ? null : () => _send(again: true),
                  child: Text(_sending ? 'Sending…' : 'Send again'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return NvAuthLayout(
      leading: back,
      title: 'Reset your PIN',
      subtitle: _email != null
          ? 'We’ll email a code to $_email. Enter it here to choose a new PIN.'
          : 'We’ll email you a code. Enter it here to choose a new PIN.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...alert,
          if (!_loadingEmail && _email == null) ...[
            NvField(
              label: 'Email',
              controller: _emailField,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _send(),
            ),
            const SizedBox(height: NvSpace.lg),
          ],
          NvButton(
            label: 'Send code',
            large: true,
            expand: true,
            loading: _sending,
            onPressed: _loadingEmail ? null : _send,
          ),
        ],
      ),
    );
  }
}

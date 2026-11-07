import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';
import '../ui/nv.dart';

class SigninPage extends StatefulWidget {
  const SigninPage({super.key});

  @override
  State<SigninPage> createState() => _SigninPageState();
}

class _SigninPageState extends State<SigninPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signin() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await ApiService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        final token = (result['data']['token'] ?? result['data']['accessToken'] ?? '').toString();
        await TokenService.storeAuthToken(token);
        TextInput.finishAutofillContext();
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/pin-verification', arguments: token);
        }
      } else {
        setState(() => _error = (result['message'] ?? 'Incorrect email or password').toString());
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Couldn’t reach Notevia. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Android and iOS hide clipboard suggestions on password fields, so offer a
  // one-tap paste for people who keep passwords in a manager.
  Future<void> _pastePassword() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _passwordController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nv;
    return NvAuthLayout(
      title: 'Sign in to Notevia',
      subtitle: 'Your private journal, on every device.',
      footer: NvAuthSwitch(
        prompt: 'New to Notevia?',
        action: 'Create an account',
        onTap: () => Navigator.of(context).pushReplacementNamed('/signup'),
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[NvAlert(_error!), const SizedBox(height: NvSpace.md)],
              NvGoogleSignIn(
                dividerLabel: 'or sign in with email',
                enabled: !_isLoading,
                onError: (e) => setState(() => _error = e),
              ),
              NvField(
                label: 'Email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Enter your email';
                  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(value)) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: NvSpace.md),
              NvField(
                label: 'Password',
                controller: _passwordController,
                obscure: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _signin(),
                validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                suffix: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Paste password',
                      onPressed: _pastePassword,
                      icon: Icon(Icons.content_paste_outlined, size: 18, color: c.muted),
                    ),
                    IconButton(
                      tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 18,
                        color: c.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: NvSpace.lg),
              NvButton(
                label: 'Sign in',
                large: true,
                expand: true,
                loading: _isLoading,
                onPressed: _signin,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

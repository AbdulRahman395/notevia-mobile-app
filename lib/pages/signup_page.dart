import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../ui/nv.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final email = _emailController.text.trim();
      final result = await ApiService.register(
        _nameController.text.trim(),
        email,
        _passwordController.text,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        Navigator.of(context).pushReplacementNamed('/verification', arguments: email);
      } else {
        setState(() => _error = (result['message'] ?? 'Couldn’t create your account').toString());
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Couldn’t reach Notevia. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nv;
    return NvAuthLayout(
      title: 'Create your account',
      subtitle: 'Only you can read what you write.',
      footer: NvAuthSwitch(
        prompt: 'Already have an account?',
        action: 'Sign in',
        onTap: () => Navigator.of(context).pushReplacementNamed('/signin'),
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[NvAlert(_error!), const SizedBox(height: NvSpace.md)],
              NvGoogleSignIn(
                dividerLabel: 'or sign up with email',
                enabled: !_isLoading,
                onError: (e) => setState(() => _error = e),
              ),
              NvField(
                label: 'Full name',
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
              ),
              const SizedBox(height: NvSpace.md),
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
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => _signup(),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Choose a password';
                  if (v.length < 6) return 'Use at least 6 characters';
                  return null;
                },
                suffix: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 18,
                    color: c.muted,
                  ),
                ),
              ),
              const SizedBox(height: NvSpace.xs),
              Text('At least 6 characters.', style: NvText.meta.copyWith(color: c.muted)),
              const SizedBox(height: NvSpace.lg),
              NvButton(
                label: 'Create account',
                large: true,
                expand: true,
                loading: _isLoading,
                onPressed: _signup,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

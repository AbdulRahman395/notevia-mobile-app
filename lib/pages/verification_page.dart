import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/toaster_service.dart';
import '../ui/nv.dart';

class VerificationPage extends StatefulWidget {
  final String email;

  const VerificationPage({super.key, required this.email});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  static const _length = 6;
  // One real field behind six boxes: paste, autofill and backspace all just work.
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _controller.text;
    if (_isLoading) return;
    if (code.length != _length) {
      setState(() => _error = 'Enter all 6 digits');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await ApiService.verifyAccount(widget.email, code);
      if (!mounted) return;
      if (result['success'] == true) {
        ToasterService.showSuccess(context, 'Email verified. Sign in to continue.');
        Navigator.of(context).pushReplacementNamed('/signin');
      } else {
        setState(() => _error = (result['message'] ?? 'That code didn’t work').toString());
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
      leading: BackButton(onPressed: () => Navigator.of(context).pushReplacementNamed('/signup')),
      title: 'Check your email',
      subtitle: 'We sent a 6-digit code to ${widget.email}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[NvAlert(_error!), const SizedBox(height: NvSpace.md)],
          NvCodeField(controller: _controller, focusNode: _focus, onCompleted: (_) => _verify()),
          const SizedBox(height: NvSpace.lg),
          NvButton(label: 'Verify email', large: true, expand: true, loading: _isLoading, onPressed: _verify),
          const SizedBox(height: NvSpace.md),
          Text(
            'Can’t find it? Check your spam folder.',
            style: NvText.meta.copyWith(color: c.muted),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';

class PinVerificationPage extends StatefulWidget {
  final String token;

  const PinVerificationPage({super.key, required this.token});

  @override
  State<PinVerificationPage> createState() => _PinVerificationPageState();
}

class _PinVerificationPageState extends State<PinVerificationPage> {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkPinStatus();
  }

  Future<void> _checkPinStatus() async {
    try {
      final result = await ApiService.hasPin(widget.token);

      if (result['requires_login_redirect'] == true) {
        if (mounted) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/signin', (Route<dynamic> route) => false);
        }
        return;
      }

      if (!result['success']) {
        print('Failed to check PIN status: ${result['message']}');
      }
    } catch (e) {
      print('Error checking PIN status: $e');
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _onTextChanged(String value, int index) {
    if (value.isNotEmpty && index < 3) {
      _focusNodes[index].unfocus();
      FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index].unfocus();
      FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
    }
  }

  String _getPIN() {
    return _controllers.map((controller) => controller.text).join();
  }

  void _verifyPIN() async {
    final pin = _getPIN();
    if (pin.length != 4) {
      _showError('Please enter all 4 digits');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.verifyPIN(widget.token, pin);

      if (mounted) {
        if (result['success']) {
          // Store access token from PIN verification response
          final accessToken =
              result['data']['accessToken'] ?? result['data']['token'] ?? '';
          if (accessToken.isNotEmpty) {
            await TokenService.storeAccessToken(accessToken);
          }

          _showSuccess('PIN verified successfully!');
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.of(context).pushReplacementNamed('/home');
            }
          });
        } else {
          _showError(result['message']);
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('PIN verification failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[600],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),

                    // Icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.lock,
                        size: 40,
                        color: Colors.blue[600],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Title
                    const Text(
                      'Enter PIN',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 10),

                    // Subtitle
                    Text(
                      'Enter your 4-digit PIN to access your account',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 30),

                    // PIN Input Fields
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(4, (index) {
                        return SizedBox(
                          width: 60,
                          height: 60,
                          child: TextFormField(
                            controller: _controllers[index],
                            focusNode: _focusNodes[index],
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            maxLength: 1,
                            obscureText: true,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.2),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (value) {
                              _onTextChanged(value, index);
                            },
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 30),

                    // Verify PIN Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _verifyPIN,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blue[600],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.blue,
                                ),
                              )
                            : const Text(
                                'Verify PIN',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Forgot PIN
                    Center(
                      child: TextButton(
                        onPressed: () {
                          // TODO: Implement forgot PIN functionality
                          _showError(
                            'Forgot PIN functionality not implemented yet',
                          );
                        },
                        child: Text(
                          'Forgot PIN?',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Create PIN
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacementNamed(
                            '/create-pin',
                            arguments: widget.token,
                          );
                        },
                        child: Text(
                          'Create New PIN',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),

                    // Add flexible space at the bottom
                    const Spacer(),
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

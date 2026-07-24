import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';
import '../services/app_lock_service.dart';
import '../services/heartbeat_service.dart';
import '../services/toaster_service.dart';

class PinVerificationPage extends StatefulWidget {
  final String token;

  const PinVerificationPage({super.key, required this.token});

  @override
  State<PinVerificationPage> createState() => _PinVerificationPageState();
}

class _PinVerificationPageState extends State<PinVerificationPage> {
  final TextEditingController _pinController = TextEditingController();
  final AppLockService _appLockService = AppLockService();
  final HeartbeatService _heartbeatService = HeartbeatService();

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
    final controller = _pinController;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
    super.dispose();
  }

  void _verifyPIN() async {
    final pin = _pinController.text;
    if (pin.length != 4) {
      _showError('Please enter all 4 digits');
      return;
    }

    try {
      final result = await ApiService.verifyPIN(widget.token, pin);

      if (mounted) {
        if (result['success']) {
          // Store access token from PIN verification response
          final accessToken =
              result['data']['accessToken'] ?? result['data']['token'] ?? '';
          if (accessToken.isNotEmpty) {
            await TokenService.storeAccessToken(accessToken);

            // Update HeartbeatService with new token
            _heartbeatService.updateToken(accessToken);
          }

          // Notify AppLockService that PIN was verified successfully
          _appLockService.unlockAfterPinVerification();

          _showSuccess('PIN verified successfully!');
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.of(context).pushReplacementNamed('/home');
            }
          });
        } else {
          _showError(result['message']);
          _pinController.clear();
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('PIN verification failed: ${e.toString()}');
        _pinController.clear();
      }
    }
  }

  void _showError(String message) {
    ToasterService.showError(context, message);
  }

  void _showSuccess(String message) {
    ToasterService.showSuccess(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pushReplacementNamed('/signin');
          },
          icon: Icon(Icons.arrow_back, color: Colors.grey[800]),
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
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),

                    // Icon badge
                    Center(
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.blue[400]!, Colors.blue[600]!],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withValues(alpha: 0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.lock_outline,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Title
                    const Text(
                      'Enter PIN',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      'Enter your 4-digit PIN to access your account',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 32),

                    // PIN Input Fields
                    PinCodeTextField(
                      appContext: context,
                      controller: _pinController,
                      length: 4,
                      obscureText: true,
                      obscuringCharacter: '●',
                      blinkWhenObscuring: true,
                      animationType: AnimationType.fade,
                      keyboardType: TextInputType.number,
                      pinTheme: PinTheme(
                        shape: PinCodeFieldShape.box,
                        borderRadius: BorderRadius.circular(14),
                        fieldHeight: 58,
                        fieldWidth: 58,
                        activeFillColor: Colors.grey[50],
                        selectedFillColor: Colors.blue[50],
                        inactiveFillColor: Colors.grey[50],
                        activeColor: Colors.grey[300]!,
                        selectedColor: Colors.blue[500]!,
                        inactiveColor: Colors.grey[300]!,
                        borderWidth: 2,
                      ),
                      enableActiveFill: true,
                      textStyle: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                      cursorColor: Colors.blue[500],
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onCompleted: (pin) {
                        _verifyPIN();
                      },
                      onChanged: (value) {
                        // Optional: Handle real-time changes if needed
                      },
                    ),

                    const SizedBox(height: 36),

                    // Forgot PIN
                    Center(
                      child: TextButton(
                        onPressed: () {
                          // TODO: Implement forgot PIN functionality
                          _showError(
                            'Forgot PIN functionality not implemented yet',
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue[500],
                        ),
                        child: const Text(
                          'Forgot PIN?',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Create PIN
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacementNamed(
                            '/create-pin',
                            arguments: widget.token,
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue[500],
                        ),
                        child: const Text(
                          'Create New PIN',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
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

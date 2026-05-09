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
    _pinController.dispose();
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
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('PIN verification failed: ${e.toString()}');
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
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

                    // Title
                    const Text(
                      'Enter PIN',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 10),

                    // Subtitle
                    Text(
                      'Enter your 4-digit PIN to access your account',
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 30),

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
                        borderRadius: BorderRadius.circular(12),
                        fieldHeight: 60,
                        fieldWidth: 60,
                        activeFillColor: Colors.grey[50],
                        selectedFillColor: Colors.grey[50],
                        inactiveFillColor: Colors.grey[50],
                        activeColor: Colors.grey[400]!,
                        selectedColor: Colors.grey[400]!,
                        inactiveColor: Colors.grey[400]!,
                        borderWidth: 2,
                      ),
                      enableActiveFill: true,
                      textStyle: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      cursorColor: Colors.black87,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onCompleted: (pin) {
                        _verifyPIN();
                      },
                      onChanged: (value) {
                        // Optional: Handle real-time changes if needed
                      },
                    ),

                    const SizedBox(height: 40),

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
                          style: TextStyle(color: Colors.blue[600]),
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
                          style: TextStyle(color: Colors.blue[600]),
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

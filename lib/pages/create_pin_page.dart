import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';
import '../services/toaster_service.dart';

class CreatePinPage extends StatefulWidget {
  final String token;

  const CreatePinPage({super.key, required this.token});

  @override
  State<CreatePinPage> createState() => _CreatePinPageState();
}

class _CreatePinPageState extends State<CreatePinPage> {
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    final controller = _pinController;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
    super.dispose();
  }

  void _createPIN() async {
    final pin = _pinController.text;
    if (pin.length != 4) {
      _showError('Please enter all 4 digits');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.createPIN(widget.token, pin);

      if (mounted) {
        if (result['success']) {
          // Store access token from PIN creation response
          final accessToken =
              result['data']['accessToken'] ?? result['data']['token'] ?? '';
          if (accessToken.isNotEmpty) {
            await TokenService.storeAccessToken(accessToken);
          }

          _showSuccess('PIN created successfully!');
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
        _showError('PIN creation failed: ${e.toString()}');
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
            Navigator.of(context).pushReplacementNamed(
              '/pin-verification',
              arguments: widget.token,
            );
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
                      'Create PIN',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      'Create a 4-digit PIN for secure access to your account',
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
                        _createPIN();
                      },
                      onChanged: (value) {
                        // Optional: Handle real-time changes if needed
                      },
                    ),

                    const SizedBox(height: 36),

                    // Create PIN Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createPIN,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[500],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Create PIN',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),

                    // Push content upward, matching verify pin layout
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

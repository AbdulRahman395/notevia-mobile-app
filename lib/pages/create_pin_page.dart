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
      backgroundColor: Colors.white,
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
                      'Create PIN',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 10),

                    // Subtitle
                    const Text(
                      'Create a 4-digit PIN for secure access to your account',
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
                        activeColor: Colors.grey[300]!,
                        selectedColor: Colors.blue[600]!,
                        inactiveColor: Colors.grey[300]!,
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
                        _createPIN();
                      },
                      onChanged: (value) {
                        // Optional: Handle real-time changes if needed
                      },
                    ),

                    const SizedBox(height: 40),

                    // Create PIN Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createPIN,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Create PIN',
                                style: TextStyle(fontSize: 16),
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

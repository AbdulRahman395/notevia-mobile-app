import 'package:flutter/material.dart';

class ToasterService {
  static OverlayEntry? _overlayEntry;
  static bool _isShowing = false;

  static void show(
    BuildContext context, {
    required String message,
    ToasterType type = ToasterType.info,
  }) {
    if (_isShowing) {
      _hide();
    }

    final mediaQueryData = MediaQuery.of(context);

    _overlayEntry = OverlayEntry(
      builder: (context) => MediaQuery(
        data: mediaQueryData,
        child: _ToasterWidget(message: message, type: type, onDismiss: _hide),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _isShowing = true;

    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      _hide();
    });
  }

  static void _hide() {
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      _isShowing = false;
    }
  }

  static void showSuccess(BuildContext context, String message) {
    show(context, message: message, type: ToasterType.success);
  }

  static void showError(BuildContext context, String message) {
    show(context, message: message, type: ToasterType.error);
  }

  static void showInfo(BuildContext context, String message) {
    show(context, message: message, type: ToasterType.info);
  }
}

enum ToasterType { success, error, info }

class _ToasterWidget extends StatefulWidget {
  final String message;
  final ToasterType type;
  final VoidCallback onDismiss;

  const _ToasterWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_ToasterWidget> createState() => _ToasterWidgetState();
}

class _ToasterWidgetState extends State<_ToasterWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutBack,
          ),
        );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    return Positioned(
      bottom: keyboardHeight > 0
          ? keyboardHeight + 20
          : 50, // Above keyboard or default position
      left: 0,
      right: 0,
      child: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8,
                minWidth: 100,
              ),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _getBackgroundColor(),
                borderRadius: BorderRadius.circular(
                  20,
                ), // Smaller capsule shape
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_getIcon(), color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        decoration:
                            TextDecoration.none, // Remove any underlining
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (widget.type) {
      case ToasterType.success:
        return const Color(0xFF424242); // Dark grey
      case ToasterType.error:
        return const Color(0xFF424242); // Dark grey
      case ToasterType.info:
        return const Color(0xFF424242); // Dark grey
    }
  }

  IconData _getIcon() {
    switch (widget.type) {
      case ToasterType.success:
        return Icons.check_circle_outline;
      case ToasterType.error:
        return Icons.error_outline;
      case ToasterType.info:
        return Icons.info_outline;
    }
  }
}

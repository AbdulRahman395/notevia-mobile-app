import 'package:flutter/material.dart';
import '../theme/tokens.dart';

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
      duration: NvMotion.short,
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: NvMotion.ease,
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
    final c = context.nv;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final iconColor = switch (widget.type) {
      ToasterType.success => c.success,
      ToasterType.error => c.danger,
      ToasterType.info => c.accent,
    };
    return Positioned(
      bottom: (keyboardHeight > 0 ? keyboardHeight : safeBottom) + NvSpace.md,
      left: NvSpace.gutter,
      right: NvSpace.gutter,
      child: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Semantics(
              liveRegion: true,
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 440),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: c.surface2,
                    borderRadius: BorderRadius.circular(NvRadius.control),
                    border: Border.all(color: c.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getIcon(), color: iconColor, size: 18),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          widget.message,
                          style: NvText.small.copyWith(color: c.fg),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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

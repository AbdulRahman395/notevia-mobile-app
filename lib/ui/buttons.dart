import 'package:flutter/material.dart';
import '../theme/tokens.dart';

enum NvButtonVariant { primary, secondary, danger, ghost }

/// The app's one button. Primary is green (Primer), one per screen.
class NvButton extends StatelessWidget {
  const NvButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = NvButtonVariant.primary,
    this.icon,
    this.leading,
    this.loading = false,
    this.expand = false,
    this.large = false,
  });

  const NvButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.leading,
    this.loading = false,
    this.expand = false,
    this.large = false,
  }) : variant = NvButtonVariant.secondary;

  const NvButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.leading,
    this.loading = false,
    this.expand = false,
    this.large = false,
  }) : variant = NvButtonVariant.danger;

  final String label;
  final VoidCallback? onPressed;
  final NvButtonVariant variant;
  final IconData? icon;

  /// A picture before the label, such as a brand logo (instead of [icon])
  final Widget? leading;
  final bool loading;
  final bool expand;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.nv;
    final enabled = onPressed != null && !loading;

    late final Color bg;
    late final Color bgPressed;
    late final Color fg;
    late final Color border;
    switch (variant) {
      case NvButtonVariant.primary:
        bg = c.primary;
        bgPressed = c.primaryPressed;
        fg = c.onPrimary;
        border = Colors.transparent;
      case NvButtonVariant.secondary:
        bg = c.surface2;
        bgPressed = Color.alphaBlend(c.pressed, c.surface2);
        fg = c.fg;
        border = c.line;
      case NvButtonVariant.danger:
        bg = c.surface2;
        bgPressed = c.dangerSoft;
        fg = c.danger;
        border = c.line;
      case NvButtonVariant.ghost:
        bg = Colors.transparent;
        bgPressed = c.pressed;
        fg = c.accent;
        border = Colors.transparent;
    }

    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(
        Size(0, large ? NvSize.controlLg : NvSize.control),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16),
      ),
      tapTargetSize: MaterialTapTargetSize.padded,
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      animationDuration: NvMotion.micro,
      textStyle: const WidgetStatePropertyAll(NvText.label),
      shape: WidgetStateProperty.resolveWith((s) {
        final focused = s.contains(WidgetState.focused);
        return RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NvRadius.control),
          side: BorderSide(
            color: focused ? c.accent : border,
            width: focused ? 2 : 1,
          ),
        );
      }),
      backgroundColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.disabled)) {
          return variant == NvButtonVariant.primary
              ? c.primary.withValues(alpha: 0.5)
              : bg;
        }
        if (s.contains(WidgetState.pressed)) return bgPressed;
        return bg;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.disabled)) {
          return variant == NvButtonVariant.primary
              ? c.onPrimary.withValues(alpha: 0.7)
              : c.subtle;
        }
        return fg;
      }),
    );

    final child = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: variant == NvButtonVariant.primary ? c.onPrimary : c.muted,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 10)]
              else if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    final button = FilledButton(
      onPressed: enabled ? onPressed : null,
      style: style,
      child: child,
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: loading ? '$label, working' : null,
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}

/// Square icon button for top bars and toolbars
class NvIconButton extends StatelessWidget {
  const NvIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.label,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    tooltip: label,
    icon: Icon(icon, size: 22, color: color),
  );
}

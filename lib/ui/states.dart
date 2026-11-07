import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'buttons.dart';

/// Grey placeholder block in the shape of what is loading.
class NvSkeleton extends StatelessWidget {
  const NvSkeleton({super.key, this.width, this.height = 12, this.radius = 4});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: context.nv.surface2,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Empty or error state: what belongs here and the one action that fills it.
class NvEmptyState extends StatelessWidget {
  const NvEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.secondary = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Use a secondary button (for "Try again")
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final c = context.nv;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: NvSpace.lg, vertical: NvSpace.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28, color: c.subtle),
          const SizedBox(height: NvSpace.sm),
          Text(
            title,
            textAlign: TextAlign.center,
            style: NvText.heading.copyWith(color: c.fg),
          ),
          if (message != null) ...[
            const SizedBox(height: NvSpace.xxs),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: NvText.small.copyWith(color: c.muted),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: NvSpace.md),
            NvButton(
              label: actionLabel!,
              onPressed: onAction,
              variant: secondary ? NvButtonVariant.secondary : NvButtonVariant.primary,
            ),
          ],
        ],
      ),
    );
  }
}

/// Confirm a destructive action in a bottom sheet. Returns true when confirmed.
Future<bool> showNvConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = true,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    builder: (context) {
      final c = context.nv;
      return Padding(
        padding: const EdgeInsets.fromLTRB(NvSpace.lg, 0, NvSpace.lg, NvSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: NvText.title.copyWith(color: c.fg)),
            const SizedBox(height: NvSpace.xs),
            Text(message, style: NvText.small.copyWith(color: c.muted)),
            const SizedBox(height: NvSpace.lg),
            NvButton(
              label: confirmLabel,
              large: true,
              expand: true,
              variant: destructive ? NvButtonVariant.danger : NvButtonVariant.primary,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: NvSpace.xs),
            NvButton.secondary(
              label: 'Cancel',
              large: true,
              expand: true,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      );
    },
  );
  return result ?? false;
}

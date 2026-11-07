import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/tokens.dart';

/// A labelled text field: the label sits above the input, Primer style.
class NvField extends StatelessWidget {
  const NvField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.labelAction,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.validator,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.inputFormatters,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;

  /// Small link on the right of the label (e.g. "Forgot password?")
  final Widget? labelAction;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization textCapitalization;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.nv;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: NvText.label.copyWith(color: c.fg)),
              ),
              ?labelAction,
            ],
          ),
        ),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          autofocus: autofocus,
          enabled: enabled,
          obscureText: obscure,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          validator: validator,
          onFieldSubmitted: onSubmitted,
          textCapitalization: textCapitalization,
          maxLines: obscure ? 1 : maxLines,
          minLines: minLines,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          style: NvText.body.copyWith(color: c.fg, height: 1.35),
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffix,
            counterStyle: NvText.caption.copyWith(color: c.muted),
            constraints: const BoxConstraints(minHeight: NvSize.controlLg),
          ),
        ),
      ],
    );
  }
}

/// Inline error message, shown above a form instead of a toast.
class NvAlert extends StatelessWidget {
  const NvAlert(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.nv;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: c.dangerSoft,
          borderRadius: BorderRadius.circular(NvRadius.control),
          border: Border.all(color: c.danger.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(Icons.error_outline, size: 18, color: c.danger),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: NvText.small.copyWith(color: c.fg)),
            ),
          ],
        ),
      ),
    );
  }
}

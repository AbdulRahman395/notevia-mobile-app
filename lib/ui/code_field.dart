import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/tokens.dart';

/// Six boxes for an emailed code. One real field sits behind them, so paste,
/// autofill and backspace all just work.
class NvCodeField extends StatefulWidget {
  const NvCodeField({
    super.key,
    required this.controller,
    this.focusNode,
    this.length = 6,
    this.onCompleted,
    this.autofocus = true,
    this.label = 'Verification code',
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final int length;
  final ValueChanged<String>? onCompleted;
  final bool autofocus;
  final String label;

  @override
  State<NvCodeField> createState() => _NvCodeFieldState();
}

class _NvCodeFieldState extends State<NvCodeField> {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _focus.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focus.removeListener(_changed);
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nv;
    final code = widget.controller.text;
    final n = widget.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.label, style: NvText.label.copyWith(color: c.fg)),
        const SizedBox(height: 6),
        Stack(
          children: [
            Row(
              children: List.generate(n, (i) {
                final active = _focus.hasFocus && (i == code.length || (i == n - 1 && code.length == n));
                return Expanded(
                  child: Container(
                    height: 52,
                    margin: EdgeInsets.only(right: i == n - 1 ? 0 : NvSpace.xs),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.inset,
                      borderRadius: BorderRadius.circular(NvRadius.control),
                      border: Border.all(color: active ? c.accent : c.line, width: active ? 2 : 1),
                    ),
                    child: Text(
                      i < code.length ? code[i] : '',
                      style: NvText.title.copyWith(color: c.fg, fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                  ),
                );
              }),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  autofocus: widget.autofocus,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  maxLength: n,
                  showCursor: false,
                  enableInteractiveSelection: false,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(counterText: '', border: InputBorder.none, filled: false),
                  onChanged: (v) {
                    if (v.length == n) widget.onCompleted?.call(v);
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

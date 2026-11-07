import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/tokens.dart';

/// Returns an error message to show, or null when the PIN was accepted.
typedef PinSubmit = Future<String?> Function(String pin);

/// Four dots and a phone-style keypad. No system keyboard, so nothing jumps.
class NvPinPad extends StatefulWidget {
  const NvPinPad({
    super.key,
    required this.onSubmit,
    this.length = 4,
    this.biometricIcon,
    this.biometricLabel,
    this.onBiometric,
    this.enabled = true,
  });

  final PinSubmit onSubmit;
  final int length;

  /// Shown bottom-left of the keypad when phone unlock is on
  final IconData? biometricIcon;
  final String? biometricLabel;
  final VoidCallback? onBiometric;
  final bool enabled;

  @override
  State<NvPinPad> createState() => NvPinPadState();
}

class NvPinPadState extends State<NvPinPad> with SingleTickerProviderStateMixin {
  String _pin = '';
  String? _error;
  bool _busy = false;
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );
  final FocusNode _focus = FocusNode(debugLabel: 'pin-pad');

  @override
  void dispose() {
    _shake.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Clear the dots (e.g. when a step changes from "create" to "confirm")
  void reset({String? error}) {
    setState(() {
      _pin = '';
      _error = error;
    });
    if (error != null) _shakeNow();
  }

  void _shakeNow() {
    HapticFeedback.heavyImpact();
    if (MediaQuery.maybeDisableAnimationsOf(context) == true) return;
    _shake.forward(from: 0);
  }

  Future<void> _press(String digit) async {
    if (_busy || !widget.enabled || _pin.length >= widget.length) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == widget.length) {
      setState(() => _busy = true);
      final error = await widget.onSubmit(_pin);
      if (!mounted) return;
      setState(() => _busy = false);
      if (error != null) reset(error: error);
    }
  }

  void _backspace() {
    if (_busy || _pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final ch = e.character;
    if (ch != null && RegExp(r'^\d$').hasMatch(ch)) {
      _press(ch);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.backspace) {
      _backspace();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nv;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _shake,
            builder: (context, child) {
              final t = _shake.value;
              final dx = math.sin(t * math.pi * 4) * 10 * (1 - t);
              return Transform.translate(offset: Offset(dx, 0), child: child);
            },
            child: Semantics(
              label: '${_pin.length} of ${widget.length} digits entered',
              liveRegion: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(widget.length, (i) {
                  final filled = i < _pin.length;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: AnimatedContainer(
                      duration: NvMotion.of(context, NvMotion.micro),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled
                            ? (_error != null ? c.danger : c.fg)
                            : Colors.transparent,
                        border: Border.all(
                          color: _error != null ? c.danger : c.lineStrong,
                          width: 1.5,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: Center(
              child: _busy
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: c.muted),
                    )
                  : Text(
                      _error ?? '',
                      textAlign: TextAlign.center,
                      style: NvText.meta.copyWith(color: c.danger),
                    ),
            ),
          ),
          _keypad(c),
        ],
      ),
    );
  }

  Widget _keypad(NvColors c) {
    Widget row(List<Widget> keys) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys,
    );
    Widget digit(String d) => _Key(
      label: d,
      onTap: () => _press(d),
      child: Text(
        d,
        style: NvText.display.copyWith(
          color: c.fg,
          fontSize: 28,
          fontWeight: FontWeight.w400,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row([digit('1'), digit('2'), digit('3')]),
          row([digit('4'), digit('5'), digit('6')]),
          row([digit('7'), digit('8'), digit('9')]),
          row([
            widget.onBiometric != null
                ? _Key(
                    label: widget.biometricLabel ?? 'Use phone unlock',
                    onTap: widget.onBiometric!,
                    child: Icon(
                      widget.biometricIcon ?? Icons.fingerprint,
                      size: 28,
                      color: c.accent,
                    ),
                  )
                : const SizedBox(width: _Key.size, height: _Key.size),
            digit('0'),
            _Key(
              label: 'Delete',
              onTap: _backspace,
              onLongPress: () => setState(() => _pin = ''),
              child: Icon(Icons.backspace_outlined, size: 24, color: c.muted),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.label,
    required this.onTap,
    required this.child,
    this.onLongPress,
  });

  static const double size = 76;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: SizedBox(
      width: size,
      height: size,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Center(child: child),
        ),
      ),
    ),
  );
}

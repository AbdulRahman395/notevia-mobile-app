import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// The ›_ prompt glyph, drawn in a 40×40 box (same paths as the web app icon).
class _GlyphPainter extends CustomPainter {
  _GlyphPainter({required this.chevron, required this.cursor, this.badge});

  final Color chevron;
  final Color cursor;
  final Color? badge;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 40;
    canvas.scale(k);
    if (badge != null) {
      canvas.drawCircle(const Offset(20, 20), 19, Paint()..color = badge!);
    }
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    // Coordinates from the web: Logo.tsx (badge) and the app icon script
    final onBadge = badge != null;
    final chevronPath = onBadge
        ? (Path()
            ..moveTo(12, 14.5)
            ..lineTo(17.5, 20)
            ..lineTo(12, 25.5))
        : (Path()
            ..moveTo(11, 14)
            ..lineTo(17, 20)
            ..lineTo(11, 26));
    canvas.drawPath(chevronPath, stroke..color = chevron);
    canvas.drawLine(
      onBadge ? const Offset(20.5, 26) : const Offset(20, 27),
      onBadge ? const Offset(28.5, 26) : const Offset(29, 27),
      stroke..color = cursor,
    );
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.chevron != chevron || old.cursor != cursor || old.badge != badge;
}

/// In-app mark: a round badge in the theme's ink with the prompt cut out.
class NvMark extends StatelessWidget {
  const NvMark({super.key, this.size = 28});
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.nv;
    return Semantics(
      label: 'Notevia',
      child: CustomPaint(
        size: Size.square(size),
        painter: _GlyphPainter(chevron: c.bg, cursor: c.bg, badge: c.fg),
      ),
    );
  }
}

/// Launcher-style glyph: blue chevron and white cursor, as on the app icon.
class NvGlyph extends StatelessWidget {
  const NvGlyph({super.key, this.size = 72});
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _GlyphPainter(chevron: NvBrand.chevron, cursor: NvBrand.cursor),
  );
}

/// Mark + wordmark
class NvLogo extends StatelessWidget {
  const NvLogo({super.key, this.size = 26});
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      NvMark(size: size),
      SizedBox(width: size * 0.36),
      Text(
        'Notevia',
        style: NvText.heading.copyWith(
          color: context.nv.fg,
          fontSize: size * 0.66,
        ),
      ),
    ],
  );
}

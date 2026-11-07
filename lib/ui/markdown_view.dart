import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// Renders a journal entry. The web saves Markdown (older entries are HTML),
/// the mobile app saves plain text; all three come through here.
///
/// Built from plain Text widgets so a parent SelectionArea can select across
/// the whole entry smoothly (flutter_html did not support that).
class NvMarkdownView extends StatelessWidget {
  const NvMarkdownView(this.source, {super.key});
  final String source;

  @override
  Widget build(BuildContext context) {
    final c = context.nv;
    final base = NvText.body.copyWith(color: c.text, height: 1.6);
    final blocks = _parseBlocks(normalizeContent(source));
    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      if (i > 0) children.add(SizedBox(height: b.kind == _Kind.listItem && blocks[i - 1].kind == _Kind.listItem ? 4 : 14));
      children.add(_buildBlock(context, b, base, c));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  Widget _buildBlock(BuildContext context, _Block b, TextStyle base, NvColors c) {
    switch (b.kind) {
      case _Kind.heading:
        final size = switch (b.level) { 1 => 22.0, 2 => 19.0, _ => 17.0 };
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text.rich(
            _inline(b.text, base.copyWith(fontSize: size, fontWeight: FontWeight.w600, color: c.fg, height: 1.35), c),
          ),
        );
      case _Kind.rule:
        return Divider(height: 1, color: c.line);
      case _Kind.quote:
        return Container(
          padding: const EdgeInsets.only(left: 14),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: c.line, width: 3))),
          child: Text.rich(_inline(b.text, base.copyWith(color: c.muted), c)),
        );
      case _Kind.code:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.inset,
            borderRadius: BorderRadius.circular(NvRadius.control),
            border: Border.all(color: c.lineMuted),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(b.text, style: NvText.code.copyWith(color: c.text)),
          ),
        );
      case _Kind.listItem:
        final marker = b.checked != null
            ? Icon(b.checked! ? Icons.check_box_outlined : Icons.check_box_outline_blank, size: 18, color: c.muted)
            : Text(b.ordinal ?? '•', style: base.copyWith(color: c.muted));
        return Padding(
          padding: EdgeInsets.only(left: 4.0 + b.level * 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                child: Padding(padding: EdgeInsets.only(top: b.checked != null ? 4 : 0), child: marker),
              ),
              Expanded(child: Text.rich(_inline(b.text, base, c))),
            ],
          ),
        );
      case _Kind.paragraph:
        return Text.rich(_inline(b.text, base, c));
    }
  }

  // ---- Inline: **bold**, *italic*, ~~strike~~, `code`, [links](…) -------------

  static final _inlinePattern = RegExp(
    r'(\*\*|__)(.+?)\1'
    r'|~~(.+?)~~'
    r'|`([^`]+)`'
    r'|!\[([^\]]*)\]\([^)]*\)'
    r'|\[([^\]]+)\]\(([^)]*)\)'
    r'|(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])'
    r'|(?<![\w_])_(?!\s)(.+?)(?<!\s)_(?![\w_])',
  );

  static InlineSpan _inline(String text, TextStyle style, NvColors c) {
    final spans = <InlineSpan>[];
    var index = 0;
    for (final m in _inlinePattern.allMatches(text)) {
      if (m.start > index) spans.add(TextSpan(text: text.substring(index, m.start)));
      if (m.group(2) != null) {
        spans.add(_inline(m.group(2)!, style.copyWith(fontWeight: FontWeight.w600), c));
      } else if (m.group(3) != null) {
        spans.add(_inline(m.group(3)!, style.copyWith(decoration: TextDecoration.lineThrough), c));
      } else if (m.group(4) != null) {
        spans.add(TextSpan(
          text: m.group(4),
          style: NvText.code.copyWith(color: c.fg, backgroundColor: c.surface2, fontSize: (style.fontSize ?? 16) - 2),
        ));
      } else if (m.group(5) != null) {
        if (m.group(5)!.isNotEmpty) spans.add(TextSpan(text: m.group(5), style: TextStyle(color: c.muted)));
      } else if (m.group(6) != null) {
        spans.add(TextSpan(
          text: m.group(6),
          style: TextStyle(color: c.accent, decoration: TextDecoration.underline, decorationColor: c.accent),
        ));
      } else {
        final inner = m.group(8) ?? m.group(9) ?? '';
        spans.add(_inline(inner, style.copyWith(fontStyle: FontStyle.italic), c));
      }
      index = m.end;
    }
    if (index < text.length) spans.add(TextSpan(text: text.substring(index)));
    return TextSpan(style: style, children: spans);
  }

  // ---- Blocks ---------------------------------------------------------------

  static final _heading = RegExp(r'^\s{0,3}(#{1,6})\s+(.*?)\s*#*\s*$');
  static final _rule = RegExp(r'^\s{0,3}([-*_])(\s*\1){2,}\s*$');
  static final _quote = RegExp(r'^\s{0,3}>\s?(.*)$');
  static final _bullet = RegExp(r'^(\s*)[-*+]\s+(?:\[([ xX])\]\s+)?(.*)$');
  static final _ordered = RegExp(r'^(\s*)(\d+)[.)]\s+(.*)$');
  static final _fence = RegExp(r'^\s{0,3}(```|~~~)');

  static List<_Block> _parseBlocks(String text) {
    final lines = text.split('\n');
    final out = <_Block>[];
    final para = <String>[];

    void flush() {
      if (para.isNotEmpty) {
        out.add(_Block(_Kind.paragraph, para.join('\n')));
        para.clear();
      }
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) {
        flush();
        continue;
      }
      if (_fence.hasMatch(line)) {
        flush();
        final code = <String>[];
        i++;
        while (i < lines.length && !_fence.hasMatch(lines[i])) {
          code.add(lines[i]);
          i++;
        }
        out.add(_Block(_Kind.code, code.join('\n')));
        continue;
      }
      final h = _heading.firstMatch(line);
      if (h != null) {
        flush();
        out.add(_Block(_Kind.heading, h.group(2)!, level: h.group(1)!.length));
        continue;
      }
      if (_rule.hasMatch(line)) {
        flush();
        out.add(_Block(_Kind.rule, ''));
        continue;
      }
      final q = _quote.firstMatch(line);
      if (q != null) {
        flush();
        final quote = <String>[q.group(1)!];
        while (i + 1 < lines.length && _quote.hasMatch(lines[i + 1])) {
          i++;
          quote.add(_quote.firstMatch(lines[i])!.group(1)!);
        }
        out.add(_Block(_Kind.quote, quote.join('\n')));
        continue;
      }
      final b = _bullet.firstMatch(line);
      if (b != null) {
        flush();
        final box = b.group(2);
        out.add(_Block(
          _Kind.listItem,
          b.group(3)!,
          level: b.group(1)!.length ~/ 2,
          checked: box == null ? null : box.toLowerCase() == 'x',
        ));
        continue;
      }
      final o = _ordered.firstMatch(line);
      if (o != null) {
        flush();
        out.add(_Block(_Kind.listItem, o.group(3)!, level: o.group(1)!.length ~/ 2, ordinal: '${o.group(2)}.'));
        continue;
      }
      para.add(line);
    }
    flush();
    return out;
  }
}

enum _Kind { paragraph, heading, quote, code, listItem, rule }

class _Block {
  _Block(this.kind, this.text, {this.level = 0, this.ordinal, this.checked});
  final _Kind kind;
  final String text;
  final int level;
  final String? ordinal;
  final bool? checked;
}

/// Line endings to \n, and older HTML entries to Markdown.
String normalizeContent(String raw) {
  var s = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (isLegacyHtml(s)) s = htmlToMarkdown(s);
  return s.trim();
}

bool isLegacyHtml(String s) =>
    RegExp(r'<\/?(p|br|strong|b|em|i|ul|ol|li|h[1-6]|div|span|blockquote|s|code|pre)\b', caseSensitive: false)
        .hasMatch(s);

String htmlToMarkdown(String html) {
  var s = html;
  String rep(String pattern, String Function(Match) f) =>
      s = s.replaceAllMapped(RegExp(pattern, caseSensitive: false, dotAll: true), f);
  rep(r'<br\s*/?>', (_) => '\n');
  rep(r'<h([1-6])[^>]*>(.*?)</h\1>', (m) => '\n\n${'#' * int.parse(m[1]!)} ${m[2]}\n\n');
  rep(r'<(strong|b)\b[^>]*>(.*?)</\1>', (m) => '**${m[2]}**');
  rep(r'<(em|i)\b[^>]*>(.*?)</\1>', (m) => '*${m[2]}*');
  rep(r'<(s|del|strike)\b[^>]*>(.*?)</\1>', (m) => '~~${m[2]}~~');
  rep(r'<code\b[^>]*>(.*?)</code>', (m) => '`${m[1]}`');
  rep(r'<li\b[^>]*>(.*?)</li>', (m) => '\n- ${m[1]!.replaceAll(RegExp(r'</?p[^>]*>'), '').trim()}');
  rep(r'<blockquote\b[^>]*>(.*?)</blockquote>', (m) => '\n\n> ${m[1]!.trim()}\n\n');
  rep(r'</(p|div|ul|ol)>', (_) => '\n\n');
  rep(r'<[^>]+>', (_) => '');
  s = s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&');
  return s.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

/// One-line preview for lists: no Markdown or HTML syntax.
String plainPreview(String raw) {
  var s = normalizeContent(raw);
  s = s
      .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
      .replaceAllMapped(RegExp(r'!\[([^\]]*)\]\([^)]*\)'), (m) => m[1]!)
      .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m[1]!)
      .replaceAll(RegExp(r'^\s{0,3}#{1,6}\s+', multiLine: true), '')
      .replaceAll(RegExp(r'^\s{0,3}>\s?', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*[-*+]\s+\[[ xX]\]\s+', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*([-*+]|\d+\.)\s+', multiLine: true), '')
      .replaceAllMapped(RegExp(r'(\*\*|__|~~)(.+?)\1'), (m) => m[2]!)
      .replaceAllMapped(RegExp(r'(\*|_)(.+?)\1'), (m) => m[2]!)
      .replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m[1]!)
      .replaceAll(RegExp(r'\s+'), ' ');
  return s.trim();
}

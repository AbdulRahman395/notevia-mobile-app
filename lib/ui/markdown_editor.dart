import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/tokens.dart';

/// Markdown editing for the journal body that shows the result, like the web
/// editor: **bold** looks bold with no stars, "# " makes a heading, "- " a bullet.
///
/// The text itself stays plain Markdown (what the server stores), so selection
/// and the keyboard behave like a normal text field. Markers are drawn with
/// zero width instead of removed, bullets / checkboxes / quote bars / dividers
/// are drawn in place of their marker character, and the cursor is kept out of
/// the hidden parts.

/// Where the line holding [at] starts.
int _lineStart(String t, int at) => at <= 0 ? 0 : t.lastIndexOf('\n', at - 1) + 1;

int _lineEnd(String t, int at) {
  final i = t.indexOf('\n', at);
  return i < 0 ? t.length : i;
}

// ---- Parsing -------------------------------------------------------------------

enum _Kind {
  /// Visible text
  text,

  /// An inline marker (** _ ~~ ` [ ](url)): drawn with zero width
  marker,

  /// Part of a line prefix (# , > , - [ ] , 1. ): hidden, the cursor stays out
  prefix,

  /// Line prefix that stays visible (list numbers, indentation)
  prefixText,
  bullet,
  checkbox,
  quoteBar,
  rule,
}

// Text formats, combined as bits
const _bold = 1,
    _italic = 2,
    _strike = 4,
    _code = 8,
    _link = 16,
    _quote = 32,
    _done = 64,
    _codeBlock = 128,
    _fence = 256;

class _Seg {
  const _Seg(this.start, this.end, this.kind, {this.fmt = 0, this.heading = 0, this.checked = false});
  final int start, end;
  final _Kind kind;
  final int fmt;
  final int heading;
  final bool checked;

  /// 1: a hidden inline marker, 2: part of a line prefix, 0: visible text
  int get mask => switch (kind) {
    _Kind.text => 0,
    _Kind.marker => 1,
    _ => 2,
  };
}

final _headingRe = RegExp(r'^(\s{0,3}(#{1,6})\s+)');
final _quoteRe = RegExp(r'^(\s{0,3})>(\s?)');
final _taskRe = RegExp(r'^(\s*)([-*+]\s+)\[([ xX])\](\s+)');
final _bulletRe = RegExp(r'^(\s*)([-*+])(\s+)');
final _orderedRe = RegExp(r'^\s*\d+[.)]\s+');
final _ruleRe = RegExp(r'^\s{0,3}([-*_])(\s*\1){2,}\s*$');
final _fenceRe = RegExp(r'^\s{0,3}(```|~~~)');

final _inlineRe = RegExp(
  r'(\*\*|__)(?=\S)(.+?)(?<=\S)\1'
  r'|~~(?=\S)(.+?)(?<=\S)~~'
  r'|`([^`]+)`'
  r'|\[([^\]]+)\]\(([^)]*)\)'
  r'|(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])'
  r'|(?<![\w_])_(?!\s)(.+?)(?<!\s)_(?![\w_])',
);

/// Splits the text into segments; every character lands in exactly one.
/// [pending] is an empty pair the cursor sits in (e.g. "****" after tapping
/// Bold with nothing selected), hidden until something is typed in it.
List<_Seg> _parse(String text, {(int, String)? pending}) {
  final segs = <_Seg>[];
  var offset = 0;
  var inFence = false;
  for (final line in text.split('\n')) {
    final end = offset + line.length;
    if (_fenceRe.hasMatch(line)) {
      segs.add(_Seg(offset, end, _Kind.text, fmt: _fence));
      inFence = !inFence;
    } else if (inFence) {
      segs.add(_Seg(offset, end, _Kind.text, fmt: _codeBlock));
    } else if (_ruleRe.hasMatch(line)) {
      final first = offset + line.indexOf(RegExp(r'[-*_]'));
      if (first > offset) segs.add(_Seg(offset, first, _Kind.prefix));
      segs.add(_Seg(first, first + 1, _Kind.rule));
      segs.add(_Seg(first + 1, end, _Kind.prefix));
    } else if (_headingRe.firstMatch(line) case final m?) {
      final p = offset + m[1]!.length;
      final level = m[2]!.length;
      segs.add(_Seg(offset, p, _Kind.prefix, heading: level));
      _inline(text, p, end, 0, level, segs, pending);
    } else if (_quoteRe.firstMatch(line) case final m?) {
      final bar = offset + m[1]!.length;
      if (bar > offset) segs.add(_Seg(offset, bar, _Kind.prefix));
      segs.add(_Seg(bar, bar + 1, _Kind.quoteBar));
      if (m[2]!.isNotEmpty) segs.add(_Seg(bar + 1, bar + 2, _Kind.prefix));
      _inline(text, offset + m.end, end, _quote, 0, segs, pending);
    } else if (_taskRe.firstMatch(line) case final m?) {
      final box = offset + m[1]!.length + m[2]!.length;
      final checked = m[3] != ' ';
      if (box > offset) segs.add(_Seg(offset, box, _Kind.prefix));
      segs.add(_Seg(box, box + 1, _Kind.checkbox, checked: checked));
      segs.add(_Seg(box + 1, offset + m.end, _Kind.prefix));
      _inline(text, offset + m.end, end, checked ? _done : 0, 0, segs, pending);
    } else if (_bulletRe.firstMatch(line) case final m?) {
      final dot = offset + m[1]!.length;
      if (dot > offset) segs.add(_Seg(offset, dot, _Kind.prefixText));
      segs.add(_Seg(dot, dot + 1, _Kind.bullet));
      segs.add(_Seg(dot + 1, offset + m.end, _Kind.prefixText));
      _inline(text, offset + m.end, end, 0, 0, segs, pending);
    } else if (_orderedRe.firstMatch(line) case final m?) {
      segs.add(_Seg(offset, offset + m.end, _Kind.prefixText));
      _inline(text, offset + m.end, end, 0, 0, segs, pending);
    } else {
      _inline(text, offset, end, 0, 0, segs, pending);
    }
    if (end < text.length) segs.add(_Seg(end, end + 1, _Kind.text)); // the line break
    offset = end + 1;
  }
  return segs;
}

void _inline(String text, int from, int to, int fmt, int heading, List<_Seg> segs, (int, String)? pending) {
  if (from >= to) return;
  final s = text.substring(from, to);
  var i = 0;
  void plain(int a, int b) {
    if (b <= a) return;
    // An empty pair waiting for typing stays hidden
    if (pending != null) {
      final (at, mark) = pending;
      final ps = at - mark.length - from, pe = at + mark.length - from;
      if (ps >= a && pe <= b) {
        if (ps > a) segs.add(_Seg(from + a, from + ps, _Kind.text, fmt: fmt, heading: heading));
        segs.add(_Seg(from + ps, from + pe, _Kind.marker, fmt: fmt, heading: heading));
        if (b > pe) segs.add(_Seg(from + pe, from + b, _Kind.text, fmt: fmt, heading: heading));
        return;
      }
    }
    segs.add(_Seg(from + a, from + b, _Kind.text, fmt: fmt, heading: heading));
  }

  void mark(int a, int b) => segs.add(_Seg(from + a, from + b, _Kind.marker, fmt: fmt, heading: heading));

  for (final m in _inlineRe.allMatches(s)) {
    plain(i, m.start);
    if (m[2] != null) {
      final o = m[1]!.length;
      mark(m.start, m.start + o);
      _inline(text, from + m.start + o, from + m.end - o, fmt | _bold, heading, segs, pending);
      mark(m.end - o, m.end);
    } else if (m[3] != null) {
      mark(m.start, m.start + 2);
      _inline(text, from + m.start + 2, from + m.end - 2, fmt | _strike, heading, segs, pending);
      mark(m.end - 2, m.end);
    } else if (m[4] != null) {
      mark(m.start, m.start + 1);
      segs.add(_Seg(from + m.start + 1, from + m.end - 1, _Kind.text, fmt: fmt | _code, heading: heading));
      mark(m.end - 1, m.end);
    } else if (m[5] != null) {
      final labelEnd = m.start + 1 + m[5]!.length;
      mark(m.start, m.start + 1);
      _inline(text, from + m.start + 1, from + labelEnd, fmt | _link, heading, segs, pending);
      mark(labelEnd, m.end);
    } else {
      mark(m.start, m.start + 1);
      _inline(text, from + m.start + 1, from + m.end - 1, fmt | _italic, heading, segs, pending);
      mark(m.end - 1, m.end);
    }
    i = m.end;
  }
  plain(i, s.length);
}

/// Per character: 0 visible, 1 hidden inline marker, 2 line prefix.
List<int> _maskOf(String text, {(int, String)? pending}) {
  final mask = List<int>.filled(text.length, 0);
  for (final s in _parse(text, pending: pending)) {
    final v = s.mask;
    if (v == 0) continue;
    for (var i = s.start; i < s.end; i++) {
      mask[i] = v;
    }
  }
  return mask;
}

// ---- Controller ------------------------------------------------------------------

class MarkdownEditingController extends TextEditingController {
  MarkdownEditingController({super.text});

  NvColors? colors;

  /// Width for divider lines (the text column's width)
  double ruleWidth = 280;

  /// An empty pair from tapping Bold/Italic/… with nothing selected:
  /// (cursor offset inside it, mark). Removed if the cursor leaves it empty.
  (int, String)? _pending;

  final Map<String, double> _advance = {};

  @override
  set value(TextEditingValue next) {
    super.value = _settle(next);
  }

  /// Keeps the cursor out of hidden markers and line prefixes, and clears an
  /// unused empty pair once the cursor moves away from it.
  TextEditingValue _settle(TextEditingValue v) {
    var text = v.text;
    var sel = v.selection;

    if (_pending case (final at, final mark)?) {
      final m = mark.length;
      final intact = at - m >= 0 && at + m <= text.length && text.substring(at - m, at + m) == '$mark$mark';
      if (!intact) {
        _pending = null;
      } else if (!(sel.isCollapsed && sel.baseOffset == at)) {
        text = text.replaceRange(at - m, at + m, '');
        int shift(int o) => o >= at + m ? o - 2 * m : (o > at - m ? at - m : o);
        sel = TextSelection(baseOffset: shift(sel.baseOffset), extentOffset: shift(sel.extentOffset));
        _pending = null;
        v = TextEditingValue(text: text, selection: sel);
      }
    }

    // An empty pair left behind (e.g. every letter of a bold word deleted)
    // would be invisible; drop it, unless it's the one waiting for typing
    final emptyPair = RegExp(r'\*\*\*\*|~~~~|____');
    if (v.selection.isValid && v.selection.isCollapsed && emptyPair.hasMatch(v.text)) {
      final keep = _pending?.$1;
      var t = v.text;
      var caret = v.selection.baseOffset;
      for (final m in emptyPair.allMatches(v.text).toList().reversed) {
        if (keep != null && keep == m.start + 2) continue;
        t = t.replaceRange(m.start, m.end, '');
        if (caret >= m.end) {
          caret -= 4;
        } else if (caret > m.start) {
          caret = m.start;
        }
      }
      if (t != v.text) {
        if (_pending case (final at, _)? when at > caret) _pending = null;
        v = TextEditingValue(
          text: t,
          selection: TextSelection.collapsed(offset: caret),
        );
      }
    }

    text = v.text;
    sel = v.selection;
    final composing = v.composing;
    if (!sel.isValid || !sel.isCollapsed || (composing.isValid && !composing.isCollapsed)) return v;
    final mask = _maskOf(text, pending: _pending);
    var at = sel.baseOffset;
    if (at > text.length) return v;

    // In a line prefix: move to just after it
    if (at < text.length && mask[at] == 2 && (at == 0 || text[at - 1] == '\n' || mask[at - 1] == 2)) {
      while (at < text.length && mask[at] == 2) {
        at++;
      }
    }
    // Inside a run of hidden markers: move to its start, so typing continues
    // the format on the left (e.g. at the end of a bold word, still bold)
    if (at > 0 && at < text.length && mask[at] == 1 && mask[at - 1] == 1) {
      while (at > 0 && mask[at - 1] == 1) {
        at--;
      }
    }
    if (at == sel.baseOffset) return v;
    return v.copyWith(selection: TextSelection.collapsed(offset: at));
  }

  double _width(String ch, TextStyle style, TextScaler scaler) {
    final key = '$ch|${style.fontSize}|${style.fontWeight}|${style.fontStyle}|${style.fontFamily}|${scaler.scale(10)}';
    // Measured between two letters, so spaces and side bearings count
    double w(String s) => (TextPainter(
      text: TextSpan(text: s, style: style.copyWith(letterSpacing: 0, wordSpacing: 0)),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout()).width;
    return _advance[key] ??= w('x${ch}x') - w('xx');
  }

  TextStyle _styleFor(_Seg s, TextStyle base, NvColors c) {
    var st = base;
    if (s.heading > 0) {
      st = st.copyWith(
        fontSize: switch (s.heading) {
          1 => 24.0,
          2 => 20.0,
          3 => 18.0,
          _ => base.fontSize,
        },
        fontWeight: FontWeight.w600,
        color: c.fg,
        height: 1.4,
      );
    }
    final f = s.fmt;
    if (f & (_codeBlock | _fence) != 0) {
      st = NvText.code.copyWith(
        color: f & _fence != 0 ? c.subtle : c.fg,
        fontSize: (base.fontSize ?? 16) - 2,
        height: base.height,
        backgroundColor: c.surface2,
      );
    }
    if (f & _quote != 0) st = st.copyWith(color: c.muted, fontStyle: FontStyle.italic);
    if (f & _bold != 0) st = st.copyWith(fontWeight: FontWeight.w700);
    if (f & _italic != 0) st = st.copyWith(fontStyle: FontStyle.italic);
    if (f & _strike != 0) st = st.copyWith(decoration: TextDecoration.lineThrough);
    if (f & _done != 0) st = st.copyWith(color: c.muted, decoration: TextDecoration.lineThrough);
    if (f & _link != 0)
      st = st.copyWith(color: c.accent, decoration: TextDecoration.underline, decorationColor: c.accent);
    if (f & _code != 0) {
      st = NvText.code.copyWith(
        color: c.fg,
        backgroundColor: c.surface2,
        fontSize: (st.fontSize ?? 16) - 1,
        height: st.height,
      );
    }
    if (s.kind == _Kind.prefixText && s.end - s.start > 0) st = st.copyWith(color: c.muted);
    return st;
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final c = colors ?? context.nv;
    final base = style ?? const TextStyle();
    final scaler = MediaQuery.textScalerOf(context);
    final lineHeight = scaler.scale(base.fontSize ?? 16) * (base.height ?? 1.3);
    final text = value.text;
    final composing = value.composing;
    final showComposing = withComposing && composing.isValid && !composing.isCollapsed;
    final children = <InlineSpan>[];

    for (final s in _parse(text, pending: _pending)) {
      if (s.start >= s.end) continue;
      final st = _styleFor(s, base, c);
      switch (s.kind) {
        case _Kind.text || _Kind.prefixText:
          if (!showComposing || s.end <= composing.start || s.start >= composing.end) {
            children.add(TextSpan(text: text.substring(s.start, s.end), style: st));
          } else {
            final a = s.start < composing.start ? composing.start : s.start;
            final b = s.end > composing.end ? composing.end : s.end;
            if (s.start < a) children.add(TextSpan(text: text.substring(s.start, a), style: st));
            children.add(
              TextSpan(
                text: text.substring(a, b),
                style: st.copyWith(decoration: TextDecoration.underline),
              ),
            );
            if (b < s.end) children.add(TextSpan(text: text.substring(b, s.end), style: st));
          }
        case _Kind.marker || _Kind.prefix:
          // Full height (the cursor keeps its size), zero width
          for (var i = s.start; i < s.end; i++) {
            final ch = text[i];
            // A line that starts with negative letter spacing shifts its first
            // visible letter left, so the first hidden character of a line is
            // drawn tiny instead (its height multiplier keeps the line height)
            if (i == 0 || text[i - 1] == '\n') {
              const tiny = 0.001;
              children.add(
                TextSpan(
                  text: ch,
                  style: st.copyWith(
                    color: Colors.transparent,
                    backgroundColor: Colors.transparent,
                    decoration: TextDecoration.none,
                    fontSize: tiny,
                    height: (st.fontSize ?? 16) * (st.height ?? 1.3) / tiny,
                    letterSpacing: 0,
                  ),
                ),
              );
              continue;
            }
            children.add(
              TextSpan(
                text: ch,
                style: st.copyWith(
                  color: Colors.transparent,
                  backgroundColor: Colors.transparent,
                  decoration: TextDecoration.none,
                  letterSpacing: -_width(ch, st, scaler),
                  wordSpacing: 0,
                ),
              ),
            );
          }
        case _Kind.bullet:
          children.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: SizedBox(
                width: 14,
                height: lineHeight,
                child: Center(
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(color: c.fg, shape: BoxShape.circle),
                  ),
                ),
              ),
            ),
          );
        case _Kind.checkbox:
          final at = s.start;
          children.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              // Raw pointer events: the text field wins the tap gesture itself
              child: _TapListener(
                onTap: () => toggleTask(at),
                child: SizedBox(
                  width: 26,
                  height: lineHeight,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 17,
                      height: 17,
                      decoration: BoxDecoration(
                        color: s.checked ? c.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: s.checked ? c.accent : c.lineStrong, width: 1.5),
                      ),
                      child: s.checked ? Icon(Icons.check, size: 13, color: c.onAccent) : null,
                    ),
                  ),
                ),
              ),
            ),
          );
        case _Kind.quoteBar:
          children.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: SizedBox(
                width: 14,
                height: lineHeight,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(color: c.lineStrong, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
              ),
            ),
          );
        case _Kind.rule:
          children.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: SizedBox(
                width: ruleWidth,
                height: lineHeight,
                child: Center(child: Container(height: 1, color: c.line)),
              ),
            ),
          );
      }
    }
    return TextSpan(style: base, children: children);
  }

  // ---- Formatting actions -----------------------------------------------------------

  /// Tick or untick the checklist item whose box is at [boxAt] (the "[").
  void toggleTask(int boxAt) {
    final t = text;
    if (boxAt + 2 >= t.length || t[boxAt] != '[') return;
    final checked = t[boxAt + 1] != ' ';
    HapticFeedback.selectionClick();
    final sel = selection;
    super.value = TextEditingValue(text: t.replaceRange(boxAt + 1, boxAt + 2, checked ? ' ' : 'x'), selection: sel);
  }

  /// The inline match of [mark] that holds the selection, if any.
  ({int start, int end, int open})? _enclosing(String mark) {
    final t = text;
    final sel = selection;
    if (!sel.isValid) return null;
    final from = _lineStart(t, sel.start);
    final to = _lineEnd(t, sel.end);
    final line = t.substring(from, to);
    final s = sel.start - from, e = sel.end - from;
    ({int start, int end, int open})? found;
    void scan(String str, int base) {
      for (final m in _inlineRe.allMatches(str)) {
        final (kind, open, inner) = m[2] != null
            ? (m[1] == '__' ? '**' : '**', m[1]!.length, m[2]!)
            : m[3] != null
            ? ('~~', 2, m[3]!)
            : m[4] != null
            ? ('`', 1, m[4]!)
            : m[5] != null
            ? ('[', 1, m[5]!)
            : ('*', 1, m[7] ?? m[8] ?? '');
        final a = base + m.start, b = base + m.end;
        if (kind == mark && s >= a && e <= b) {
          found = (start: from + a, end: from + b, open: open);
          return;
        }
        if (s >= a && e <= b && kind != '`') scan(inner, a + open);
      }
    }

    scan(line, 0);
    return found;
  }

  /// Bold / italic / strikethrough / code. Unwraps when the selection is
  /// already inside that format; otherwise wraps the selection, or with
  /// nothing selected starts typing in that format.
  void toggleInline(String mark) {
    final t = text;
    final sel = selection.isValid ? selection : TextSelection.collapsed(offset: t.length);
    final m = mark.length;

    // Inside an empty pair from a moment ago: take it out again
    if (_pending case (final at, final pm)? when pm == mark && sel.isCollapsed && sel.baseOffset == at) {
      _pending = null;
      super.value = TextEditingValue(
        text: t.replaceRange(at - m, at + m, ''),
        selection: TextSelection.collapsed(offset: at - m),
      );
      return;
    }

    final hit = _enclosing(mark);
    if (hit != null) {
      final o = hit.open;
      final unwrapped = t.replaceRange(hit.end - o, hit.end, '').replaceRange(hit.start, hit.start + o, '');
      int shift(int x) => (x - o).clamp(hit.start, hit.end - 2 * o);
      _pending = null;
      super.value = TextEditingValue(
        text: unwrapped,
        selection: TextSelection(baseOffset: shift(sel.baseOffset), extentOffset: shift(sel.extentOffset)),
      );
      return;
    }

    final selected = t.substring(sel.start, sel.end);
    final lead = selected.length - selected.trimLeft().length;
    final trail = selected.length - selected.trimRight().length;
    final a = sel.start + lead, b = sel.end - trail;
    if (a >= b) {
      final at = sel.start + m;
      _pending = (at, mark);
      super.value = TextEditingValue(
        text: t.replaceRange(sel.start, sel.end, '$mark$mark'),
        selection: TextSelection.collapsed(offset: at),
      );
      return;
    }
    super.value = TextEditingValue(
      text: t.replaceRange(a, b, '$mark${t.substring(a, b)}$mark'),
      selection: TextSelection(baseOffset: a + m, extentOffset: b + m),
    );
  }

  /// Makes the selection (or [label]) a link to [url].
  void insertLink(String url, {String? label}) {
    final t = text;
    final sel = selection.isValid ? selection : TextSelection.collapsed(offset: t.length);
    final selected = sel.textInside(t).trim();
    final shown = selected.isNotEmpty ? selected : ((label ?? '').trim().isNotEmpty ? label!.trim() : url);
    final inserted = '[$shown]($url)';
    value = TextEditingValue(
      text: t.replaceRange(sel.start, sel.end, inserted),
      selection: TextSelection.collapsed(offset: sel.start + inserted.length),
    );
  }

  static final _anyPrefix = RegExp(
    r'^(\s{0,3}#{1,6}\s+|\s{0,3}>\s?|\s*[-*+]\s+\[[ xX]\]\s+|\s*[-*+]\s+|\s*\d+[.)]\s+)',
  );

  /// Block formats apply to every line in the selection. Pressing the active
  /// one again turns it off; a different one replaces it.
  void toggleBlock(MdBlock block) {
    final t = text;
    final sel = selection.isValid ? selection : TextSelection.collapsed(offset: t.length);
    final from = _lineStart(t, sel.start);
    final to = _lineEnd(t, sel.end);
    final lines = t.substring(from, to).split('\n');
    final filled = lines.where((l) => l.trim().isNotEmpty);
    final allOn = filled.isNotEmpty && filled.every(block.matches);

    var n = 0;
    final out = lines
        .map((line) {
          final body = line.replaceFirst(_anyPrefix, '');
          if (allOn) return body;
          if (line.trim().isEmpty && lines.length > 1) return line;
          n++;
          return '${block.prefix(n)}$body';
        })
        .join('\n');

    final delta = out.length - (to - from);
    _pending = null;
    value = TextEditingValue(
      text: t.replaceRange(from, to, out),
      selection: sel.isCollapsed
          ? TextSelection.collapsed(offset: (sel.end + delta).clamp(from, from + out.length))
          : TextSelection(baseOffset: from, extentOffset: from + out.length),
    );
  }

  /// ``` fences around the selected lines (or an empty block at the cursor).
  void toggleCodeBlock() {
    final t = text;
    final sel = selection.isValid ? selection : TextSelection.collapsed(offset: t.length);
    final from = _lineStart(t, sel.start);
    final to = _lineEnd(t, sel.end);
    final block = t.substring(from, to);
    _pending = null;
    if (block.trim().isEmpty) {
      value = TextEditingValue(
        text: t.replaceRange(from, to, '```\n\n```'),
        selection: TextSelection.collapsed(offset: from + 4),
      );
      return;
    }
    final out = '```\n$block\n```';
    value = TextEditingValue(
      text: t.replaceRange(from, to, out),
      selection: TextSelection.collapsed(offset: from + out.length),
    );
  }

  void insertDivider() {
    final t = text;
    final at = selection.isValid ? selection.end : t.length;
    final before = at == 0 || t[at - 1] == '\n' ? '' : '\n';
    final insert = '$before---\n';
    _pending = null;
    value = TextEditingValue(
      text: t.replaceRange(at, at, insert),
      selection: TextSelection.collapsed(offset: at + insert.length),
    );
  }

  /// The block format of the line the cursor is on, for the toolbar.
  MdBlock? get currentBlock {
    final t = text;
    final at = selection.isValid ? selection.start : t.length;
    final line = t.substring(_lineStart(t, at), _lineEnd(t, at));
    for (final b in MdBlock.values) {
      if (b.matches(line)) return b;
    }
    return null;
  }

  /// True when the selection (or the cursor) sits inside this inline format.
  bool isInline(String mark) {
    if (_pending case (final at, final pm)? when pm == mark && selection.isCollapsed && selection.baseOffset == at) {
      return true;
    }
    return _enclosing(mark) != null;
  }

  /// The text to save: an unused empty pair is dropped.
  String get markdown {
    if (_pending case (final at, final mark)?) {
      final m = mark.length;
      final t = text;
      if (at - m >= 0 && at + m <= t.length && t.substring(at - m, at + m) == '$mark$mark') {
        return t.replaceRange(at - m, at + m, '');
      }
    }
    return text;
  }
}

enum MdBlock {
  h1,
  h2,
  h3,
  bullet,
  numbered,
  checklist,
  quote;

  String prefix(int n) => switch (this) {
    MdBlock.h1 => '# ',
    MdBlock.h2 => '## ',
    MdBlock.h3 => '### ',
    MdBlock.bullet => '- ',
    MdBlock.numbered => '$n. ',
    MdBlock.checklist => '- [ ] ',
    MdBlock.quote => '> ',
  };

  bool matches(String line) => switch (this) {
    MdBlock.h1 => RegExp(r'^\s{0,3}#\s').hasMatch(line),
    MdBlock.h2 => RegExp(r'^\s{0,3}##\s').hasMatch(line),
    MdBlock.h3 => RegExp(r'^\s{0,3}###\s').hasMatch(line),
    MdBlock.checklist => RegExp(r'^\s*[-*+]\s+\[[ xX]\]\s').hasMatch(line),
    MdBlock.bullet => RegExp(r'^\s*[-*+]\s+(?!\[[ xX]\]\s)').hasMatch(line),
    MdBlock.numbered => RegExp(r'^\s*\d+[.)]\s').hasMatch(line),
    MdBlock.quote => RegExp(r'^\s{0,3}>').hasMatch(line),
  };
}

/// Keeps typing natural around hidden Markdown:
/// - Enter in a list starts the next item; Enter on an empty item ends the list.
/// - Enter at the end of a bold word puts the line break after its hidden "**".
/// - Backspace deletes the letter you see, not a hidden marker, and at the start
///   of a bullet / heading / quote removes that format first.
class MarkdownListFormatter extends TextInputFormatter {
  static final _item = RegExp(r'^(\s*)([-*+]\s+\[[ xX]\]\s+|[-*+]\s+|(\d+)([.)])\s+|>\s?)');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final sel = oldValue.selection;
    if (!sel.isValid || !sel.isCollapsed || !newValue.selection.isCollapsed) return newValue;
    final t = oldValue.text;
    final at = sel.start;

    // Backspace: one character before the cursor removed
    if (newValue.text.length == t.length - 1 &&
        at > 0 &&
        newValue.selection.start == at - 1 &&
        newValue.text == t.replaceRange(at - 1, at, '')) {
      return _backspace(oldValue, newValue);
    }

    // Enter
    if (newValue.text.length != t.length + 1) return newValue;
    if (newValue.selection.start != at + 1 || newValue.text[at] != '\n') return newValue;
    if (newValue.text.substring(0, at) != t.substring(0, at)) return newValue;

    // After hidden closing markers, so "**bold**" isn't split across lines
    final mask = _maskOf(t);
    var p = at;
    while (p < t.length && mask[p] == 1) {
      p++;
    }

    final from = _lineStart(t, p);
    final line = t.substring(from, p);
    final m = _item.firstMatch(line);
    final restEmpty = t.substring(p, _lineEnd(t, p)).trim().isEmpty;
    if (m == null || !restEmpty) {
      if (p == at) return newValue;
      return TextEditingValue(
        text: t.replaceRange(p, p, '\n'),
        selection: TextSelection.collapsed(offset: p + 1),
      );
    }

    if (line.substring(m.end).trim().isEmpty) {
      // Empty item: end the list, leaving a blank line
      return TextEditingValue(
        text: t.replaceRange(from, p, ''),
        selection: TextSelection.collapsed(offset: from),
      );
    }
    var marker = m[2]!;
    if (m[3] != null) {
      marker = '${int.parse(m[3]!) + 1}${m[4]} ';
    } else if (marker.contains('[')) {
      marker = marker.replaceFirst(RegExp(r'\[[xX]\]'), '[ ]');
    }
    final insert = '\n${m[1]}$marker';
    return TextEditingValue(
      text: t.replaceRange(p, p, insert),
      selection: TextSelection.collapsed(offset: p + insert.length),
    );
  }

  TextEditingValue _backspace(TextEditingValue oldValue, TextEditingValue newValue) {
    final t = oldValue.text;
    final mask = _maskOf(t);
    var k = oldValue.selection.start - 1;

    // Skip hidden markers to the letter you can see
    while (k >= 0 && mask[k] == 1) {
      k--;
    }
    if (k < 0) return oldValue;

    if (mask[k] == 2) {
      // At the start of a formatted line: remove the bullet / heading / quote
      var a = k;
      while (a > 0 && mask[a - 1] == 2) {
        a--;
      }
      var b = k + 1;
      while (b < t.length && mask[b] == 2) {
        b++;
      }
      final caret = oldValue.selection.start - (b - a);
      return TextEditingValue(
        text: t.replaceRange(a, b, ''),
        selection: TextSelection.collapsed(offset: caret),
      );
    }
    if (k == oldValue.selection.start - 1) return newValue;

    var text = t.replaceRange(k, k + 1, '');
    var caret = oldValue.selection.start - 1;
    // That was the only letter between a pair of markers: drop the pair
    for (final mark in const ['**', '__', '~~', '`', '*', '_']) {
      final m = mark.length;
      if (k - m >= 0 && k + m <= text.length && text.substring(k - m, k + m) == '$mark$mark') {
        text = text.replaceRange(k - m, k + m, '');
        caret = k - m;
        break;
      }
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret),
    );
  }
}

/// Asks for a link's address, then inserts it.
Future<void> promptLink(BuildContext context, MarkdownEditingController controller) async {
  final sel = controller.selection;
  final hasText = sel.isValid && !sel.isCollapsed;
  final url = TextEditingController(text: 'https://');
  final label = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add link'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!hasText) ...[
            TextField(
              controller: label,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Text'),
            ),
            const SizedBox(height: NvSpace.sm),
          ],
          TextField(
            controller: url,
            autofocus: hasText,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'Link'),
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.of(context).pop(url.text), child: const Text('Add')),
      ],
    ),
  );
  final address = result?.trim() ?? '';
  if (address.isEmpty || address == 'https://') return;
  controller.selection = sel;
  controller.insertLink(address, label: label.text);
}

/// Bold, Italic and friends in the long-press menu, before the usual items.
Widget markdownContextMenu(BuildContext context, EditableTextState state, MarkdownEditingController controller) {
  final hasSelection = !state.textEditingValue.selection.isCollapsed;
  void run(VoidCallback action) {
    state.hideToolbar();
    action();
  }

  final format = hasSelection
      ? <ContextMenuButtonItem>[
          ContextMenuButtonItem(label: 'Bold', onPressed: () => run(() => controller.toggleInline('**'))),
          ContextMenuButtonItem(label: 'Italic', onPressed: () => run(() => controller.toggleInline('*'))),
        ]
      : const <ContextMenuButtonItem>[];
  final more = hasSelection
      ? <ContextMenuButtonItem>[
          ContextMenuButtonItem(label: 'Strikethrough', onPressed: () => run(() => controller.toggleInline('~~'))),
          ContextMenuButtonItem(label: 'Code', onPressed: () => run(() => controller.toggleInline('`'))),
          ContextMenuButtonItem(label: 'Link', onPressed: () => run(() => promptLink(context, controller))),
          ContextMenuButtonItem(label: 'Heading', onPressed: () => run(() => controller.toggleBlock(MdBlock.h2))),
          ContextMenuButtonItem(label: 'Quote', onPressed: () => run(() => controller.toggleBlock(MdBlock.quote))),
        ]
      : const <ContextMenuButtonItem>[];

  return AdaptiveTextSelectionToolbar.buttonItems(
    anchors: state.contextMenuAnchors,
    buttonItems: [...format, ...state.contextMenuButtonItems, ...more],
  );
}

/// The formatting row above the keyboard.
class MarkdownToolbar extends StatelessWidget {
  const MarkdownToolbar({super.key, required this.controller, required this.undo, this.leading = const []});

  final MarkdownEditingController controller;
  final UndoHistoryController undo;
  final List<Widget> leading;

  @override
  Widget build(BuildContext context) {
    final c = context.nv;
    // Part of the text field's tap region, so tapping a tool keeps the keyboard up
    return TextFieldTapRegion(
      child: ListenableBuilder(
        listenable: Listenable.merge([controller, undo]),
        builder: (context, _) {
          final block = controller.currentBlock;
          Widget tool(String label, VoidCallback? onTap, {IconData? icon, String? text, bool active = false}) =>
              _Tool(label: label, onTap: onTap, icon: icon, text: text, active: active, colors: c);
          Widget gap() =>
              Container(width: 1, height: 20, margin: const EdgeInsets.symmetric(horizontal: 4), color: c.lineMuted);

          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            children: [
              ...leading,
              tool('Undo', undo.value.canUndo ? undo.undo : null, icon: Icons.undo),
              tool('Redo', undo.value.canRedo ? undo.redo : null, icon: Icons.redo),
              gap(),
              tool(
                'Bold',
                () => controller.toggleInline('**'),
                icon: Icons.format_bold,
                active: controller.isInline('**'),
              ),
              tool(
                'Italic',
                () => controller.toggleInline('*'),
                icon: Icons.format_italic,
                active: controller.isInline('*'),
              ),
              tool(
                'Strikethrough',
                () => controller.toggleInline('~~'),
                icon: Icons.format_strikethrough,
                active: controller.isInline('~~'),
              ),
              tool('Heading 1', () => controller.toggleBlock(MdBlock.h1), text: 'H1', active: block == MdBlock.h1),
              tool('Heading 2', () => controller.toggleBlock(MdBlock.h2), text: 'H2', active: block == MdBlock.h2),
              tool('Heading 3', () => controller.toggleBlock(MdBlock.h3), text: 'H3', active: block == MdBlock.h3),
              gap(),
              tool(
                'Bulleted list',
                () => controller.toggleBlock(MdBlock.bullet),
                icon: Icons.format_list_bulleted,
                active: block == MdBlock.bullet,
              ),
              tool(
                'Numbered list',
                () => controller.toggleBlock(MdBlock.numbered),
                icon: Icons.format_list_numbered,
                active: block == MdBlock.numbered,
              ),
              tool(
                'Checklist',
                () => controller.toggleBlock(MdBlock.checklist),
                icon: Icons.checklist,
                active: block == MdBlock.checklist,
              ),
              tool(
                'Quote',
                () => controller.toggleBlock(MdBlock.quote),
                icon: Icons.format_quote,
                active: block == MdBlock.quote,
              ),
              gap(),
              tool(
                'Inline code',
                () => controller.toggleInline('`'),
                icon: Icons.code,
                active: controller.isInline('`'),
              ),
              tool('Code block', controller.toggleCodeBlock, icon: Icons.data_object),
              tool('Link', () => promptLink(context, controller), icon: Icons.link),
              tool('Divider', controller.insertDivider, icon: Icons.horizontal_rule),
            ],
          );
        },
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({
    required this.label,
    required this.onTap,
    required this.colors,
    this.icon,
    this.text,
    this.active = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final String? text;
  final bool active;
  final NvColors colors;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final color = onTap == null ? c.subtle : (active ? c.accent : c.fg);
    return Semantics(
      button: true,
      selected: active,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Material(
            color: active ? c.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(NvRadius.control),
            child: InkWell(
              borderRadius: BorderRadius.circular(NvRadius.control),
              onTap: onTap == null
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      onTap!();
                    },
              child: SizedBox(
                width: 40,
                child: Center(
                  child: icon != null
                      ? Icon(icon, size: 20, color: color)
                      : Text(
                          text!,
                          style: NvText.label.copyWith(color: color, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A tap from raw pointer events, for widgets inside the text field.
class _TapListener extends StatefulWidget {
  const _TapListener({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_TapListener> createState() => _TapListenerState();
}

class _TapListenerState extends State<_TapListener> {
  Offset? _down;

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.opaque,
    onPointerDown: (e) => _down = e.position,
    onPointerCancel: (_) => _down = null,
    onPointerUp: (e) {
      final down = _down;
      _down = null;
      if (down != null && (e.position - down).distance < 12) widget.onTap();
    },
    child: widget.child,
  );
}

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/tokens.dart';

enum DayType { active, frozen, empty }

class DayInfo {
  const DayInfo(this.type, this.count);
  final DayType type;

  /// Null when the backend does not send per-day counts
  final int? count;

  bool get written => (count ?? 0) > 0 || type == DayType.active;
}

String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

/// First day shown: the Sunday [weeks - 1] weeks before this week's Sunday.
DateTime activityStart(DateTime today, int weeks) {
  final t = DateTime(today.year, today.month, today.day);
  return t.subtract(Duration(days: t.weekday % 7 + (weeks - 1) * 7));
}

/// Loads every month the grid touches from /streaks/history.
/// Returns null when every request failed.
Future<Map<String, DayInfo>?> loadActivity(String token, {int weeks = 26}) async {
  final today = DateTime.now();
  final start = activityStart(today, weeks);
  final months = <(int, int)>[];
  var cursor = DateTime(start.year, start.month);
  while (!cursor.isAfter(today)) {
    months.add((cursor.month, cursor.year));
    cursor = DateTime(cursor.year, cursor.month + 1);
  }
  final results = await Future.wait(
    months.map((m) => ApiService.getStreakHistory(token, m.$1, m.$2)),
  );
  final map = <String, DayInfo>{};
  var anyOk = false;
  for (final r in results) {
    if (r['success'] != true) continue;
    anyOk = true;
    final data = r['data'];
    final list = data is List ? data : (data is Map && data['data'] is List ? data['data'] as List : const []);
    for (final e in list) {
      if (e is! Map) continue;
      final date = e['date']?.toString();
      final type = switch (e['type']) {
        'active' => DayType.active,
        'frozen' => DayType.frozen,
        _ => DayType.empty,
      };
      if (date == null || date.length < 10) continue;
      map[date.substring(0, 10)] = DayInfo(type, e['count'] is num ? (e['count'] as num).toInt() : null);
    }
  }
  return anyOk ? map : null;
}

/// GitHub-style grid of written days. Scrolls sideways, starting at this week.
class NvActivityCalendar extends StatefulWidget {
  const NvActivityCalendar({
    super.key,
    required this.days,
    required this.loading,
    this.weeks = 26,
    this.onRetry,
  });

  /// Null while loading or when it failed
  final Map<String, DayInfo>? days;
  final bool loading;
  final int weeks;
  final VoidCallback? onRetry;

  @override
  State<NvActivityCalendar> createState() => _NvActivityCalendarState();
}

class _NvActivityCalendarState extends State<NvActivityCalendar> {
  static const double cell = 13;
  static const double gap = 3;
  DateTime? _selected;

  @override
  Widget build(BuildContext context) {
    final c = context.nv;
    final today = DateTime.now();
    final todayKey = dayKey(today);
    final start = activityStart(today, widget.weeks);
    final days = widget.days ?? const <String, DayInfo>{};
    final hasCounts = days.values.any((d) => d.count != null);

    var entries = 0;
    var written = 0;
    for (var i = 0; i < widget.weeks * 7; i++) {
      final d = start.add(Duration(days: i));
      if (d.isAfter(today)) break;
      final info = days[dayKey(d)];
      if (info == null) continue;
      if (info.written) written++;
      entries += info.count ?? 0;
    }

    Color colorFor(DayInfo? info) {
      if (info == null) return c.heat0;
      final n = info.count ?? (info.type == DayType.active ? 3 : 0);
      if (n <= 0) return info.type == DayType.frozen ? c.frozen.withValues(alpha: 0.55) : c.heat0;
      return [c.heat1, c.heat2, c.heat3, c.heat4][(n.clamp(1, 4)) - 1];
    }

    String summary() {
      if (widget.loading) return 'Loading activity';
      if (widget.days == null) return 'Activity is unavailable right now';
      if (hasCounts) {
        return '$entries ${entries == 1 ? 'entry' : 'entries'} in the last ${(widget.weeks / 4.345).round()} months';
      }
      return '$written ${written == 1 ? 'day' : 'days'} written in the last ${(widget.weeks / 4.345).round()} months';
    }

    String detail(DateTime d) {
      final info = days[dayKey(d)];
      final label = '${d.day} ${_months[d.month - 1]}';
      final n = info?.count;
      if (n != null && n > 0) return '$n ${n == 1 ? 'entry' : 'entries'} on $label';
      if (info?.type == DayType.frozen) return 'Streak freeze used on $label';
      if (info?.type == DayType.active) return 'Wrote on $label';
      return 'Nothing written on $label';
    }

    // Month labels above the first week that starts in a new month
    final monthLabels = <int, String>{};
    var lastMonth = -1;
    for (var w = 0; w < widget.weeks; w++) {
      final d = start.add(Duration(days: w * 7));
      if (d.month != lastMonth) {
        if (w < widget.weeks - 1) monthLabels[w] = _months[d.month - 1].substring(0, 3);
        lastMonth = d.month;
      }
    }

    final grid = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(widget.weeks, (w) {
        return Padding(
          padding: EdgeInsets.only(right: w == widget.weeks - 1 ? 0 : gap),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: cell,
                height: 16,
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  maxWidth: 40,
                  child: Text(monthLabels[w] ?? '', style: NvText.caption.copyWith(color: c.muted, fontSize: 11)),
                ),
              ),
              ...List.generate(7, (dow) {
                final d = start.add(Duration(days: w * 7 + dow));
                final future = d.isAfter(today);
                final key = dayKey(d);
                final isSelected = _selected != null && dayKey(_selected!) == key;
                return Padding(
                  padding: EdgeInsets.only(bottom: dow == 6 ? 0 : gap),
                  child: GestureDetector(
                    onTap: future || widget.loading ? null : () => setState(() => _selected = isSelected ? null : d),
                    child: Container(
                      width: cell,
                      height: cell,
                      decoration: BoxDecoration(
                        color: future ? Colors.transparent : (widget.loading ? c.heat0 : colorFor(days[key])),
                        borderRadius: BorderRadius.circular(3),
                        border: isSelected
                            ? Border.all(color: c.fg, width: 1.5)
                            : key == todayKey
                                ? Border.all(color: c.lineStrong)
                                : null,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      }),
    );

    Widget legendCell(Color color) => Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, right: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(7, (dow) {
                  const names = ['', 'Mon', '', 'Wed', '', 'Fri', ''];
                  return SizedBox(
                    height: cell + (dow == 6 ? 0 : gap),
                    child: Text(names[dow], style: NvText.caption.copyWith(color: c.muted, fontSize: 10, height: 1.2)),
                  );
                }),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                physics: const ClampingScrollPhysics(),
                child: grid,
              ),
            ),
          ],
        ),
        const SizedBox(height: NvSpace.sm),
        Row(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: NvMotion.of(context, NvMotion.micro),
                child: Text(
                  _selected != null ? detail(_selected!) : summary(),
                  key: ValueKey(_selected?.toIso8601String() ?? summary()),
                  style: NvText.meta.copyWith(color: _selected != null ? c.fg : c.muted),
                ),
              ),
            ),
            if (widget.days == null && !widget.loading && widget.onRetry != null)
              TextButton(onPressed: widget.onRetry, child: const Text('Retry'))
            else ...[
              Text('Less', style: NvText.caption.copyWith(color: c.muted, fontSize: 11)),
              const SizedBox(width: 4),
              legendCell(c.heat0),
              legendCell(c.heat1),
              legendCell(c.heat2),
              legendCell(c.heat3),
              legendCell(c.heat4),
              const SizedBox(width: 4),
              Text('More', style: NvText.caption.copyWith(color: c.muted, fontSize: 11)),
            ],
          ],
        ),
      ],
    );
  }
}

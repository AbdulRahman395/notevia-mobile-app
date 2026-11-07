import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// Moods, in the same order and names as the web app. The API stores the name.
enum Mood { happy, calm, neutral, sad }

extension MoodX on Mood {
  String get label => switch (this) {
    Mood.happy => 'Happy',
    Mood.calm => 'Calm',
    Mood.neutral => 'Neutral',
    Mood.sad => 'Sad',
  };

  Color color(NvColors c) => switch (this) {
    Mood.happy => c.moodHappy,
    Mood.calm => c.moodCalm,
    Mood.neutral => c.moodNeutral,
    Mood.sad => c.moodSad,
  };

  static Mood? parse(Object? value) {
    final s = value?.toString().toLowerCase().trim();
    for (final m in Mood.values) {
      if (m.name == s) return m;
    }
    return null;
  }
}

/// Mood shown as data: a coloured swatch and the word.
class NvMoodTag extends StatelessWidget {
  const NvMoodTag(this.mood, {super.key});
  final Mood mood;

  @override
  Widget build(BuildContext context) {
    final c = context.nv;
    final color = mood.color(c);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(mood.label, style: NvText.meta.copyWith(color: c.muted)),
      ],
    );
  }
}

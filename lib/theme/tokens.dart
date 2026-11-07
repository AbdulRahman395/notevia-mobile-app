// Notevia design tokens for the mobile app.
//
// Hallmark · app screen · theme: brand (the web app's Primer palette, carbon dark + light)
// shape: app screen · signature: the calendar of written days, and the PIN pad lock
//
// Every colour and text style in the app comes from here. Pages never use
// Colors.* or literal hex values; they read `context.nv` and `NvText`.
import 'package:flutter/material.dart';

@immutable
class NvColors extends ThemeExtension<NvColors> {
  const NvColors({
    required this.bg,
    required this.panel,
    required this.surface,
    required this.surface2,
    required this.inset,
    required this.line,
    required this.lineMuted,
    required this.lineStrong,
    required this.fg,
    required this.text,
    required this.muted,
    required this.subtle,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
    required this.primary,
    required this.primaryPressed,
    required this.onPrimary,
    required this.danger,
    required this.dangerSoft,
    required this.success,
    required this.attention,
    required this.heat0,
    required this.heat1,
    required this.heat2,
    required this.heat3,
    required this.heat4,
    required this.frozen,
    required this.moodHappy,
    required this.moodCalm,
    required this.moodNeutral,
    required this.moodSad,
    required this.scrim,
    required this.pressed,
  });

  /// App canvas
  final Color bg;

  /// Second neutral: top bars, sheets, grouped backgrounds
  final Color panel;

  /// Cards and boxes on the canvas
  final Color surface;
  final Color surface2;

  /// Inputs and wells
  final Color inset;

  /// Box borders
  final Color line;

  /// Row dividers inside a box
  final Color lineMuted;
  final Color lineStrong;

  /// Headings and strong text
  final Color fg;

  /// Body text
  final Color text;

  /// Secondary text (meta, captions)
  final Color muted;

  /// Placeholders and disabled text
  final Color subtle;

  /// Links, focus, current selection
  final Color accent;
  final Color accentSoft;
  final Color onAccent;

  /// The one primary action per screen
  final Color primary;
  final Color primaryPressed;
  final Color onPrimary;

  final Color danger;
  final Color dangerSoft;
  final Color success;
  final Color attention;

  /// Activity calendar shades (no entries … 4+ entries)
  final Color heat0;
  final Color heat1;
  final Color heat2;
  final Color heat3;
  final Color heat4;
  final Color frozen;

  final Color moodHappy;
  final Color moodCalm;
  final Color moodNeutral;
  final Color moodSad;

  final Color scrim;

  /// Pressed-state wash for rows and keys
  final Color pressed;

  static const dark = NvColors(
    bg: Color(0xFF0D1117),
    panel: Color(0xFF010409),
    surface: Color(0xFF0D1117),
    surface2: Color(0xFF151B23),
    inset: Color(0xFF010409),
    line: Color(0xFF3D444D),
    lineMuted: Color(0xFF262C36),
    lineStrong: Color(0xFF656C76),
    fg: Color(0xFFF0F6FC),
    text: Color(0xFFE6EDF3),
    muted: Color(0xFF9198A1),
    subtle: Color(0xFF656C76),
    accent: Color(0xFF4493F8),
    accentSoft: Color(0x264493F8),
    onAccent: Color(0xFFFFFFFF),
    primary: Color(0xFF238636),
    primaryPressed: Color(0xFF29903B),
    onPrimary: Color(0xFFFFFFFF),
    danger: Color(0xFFF85149),
    dangerSoft: Color(0x1AF85149),
    success: Color(0xFF3FB950),
    attention: Color(0xFFD29922),
    heat0: Color(0xFF151B23),
    heat1: Color(0xFF033A16),
    heat2: Color(0xFF196C2E),
    heat3: Color(0xFF2EA043),
    heat4: Color(0xFF56D364),
    frozen: Color(0xFF79C0FF),
    moodHappy: Color(0xFFE3B341),
    moodCalm: Color(0xFF39C5CF),
    moodNeutral: Color(0xFF8B949E),
    moodSad: Color(0xFFA371F7),
    scrim: Color(0xB3010409),
    pressed: Color(0x1FB1BAC4),
  );

  static const light = NvColors(
    bg: Color(0xFFFFFFFF),
    panel: Color(0xFFF6F8FA),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF6F8FA),
    inset: Color(0xFFF6F8FA),
    line: Color(0xFFD1D9E0),
    lineMuted: Color(0xFFE6EAEF),
    lineStrong: Color(0xFFB6C0CA),
    fg: Color(0xFF1F2328),
    text: Color(0xFF1F2328),
    muted: Color(0xFF59636E),
    subtle: Color(0xFF818B98),
    accent: Color(0xFF0969DA),
    accentSoft: Color(0x1A0969DA),
    onAccent: Color(0xFFFFFFFF),
    primary: Color(0xFF1F883D),
    primaryPressed: Color(0xFF1C8139),
    onPrimary: Color(0xFFFFFFFF),
    danger: Color(0xFFD1242F),
    dangerSoft: Color(0x14D1242F),
    success: Color(0xFF1A7F37),
    attention: Color(0xFF9A6700),
    heat0: Color(0xFFEFF2F5),
    heat1: Color(0xFFACEEBB),
    heat2: Color(0xFF4AC26B),
    heat3: Color(0xFF2DA44E),
    heat4: Color(0xFF116329),
    frozen: Color(0xFF54AEFF),
    moodHappy: Color(0xFFBF8700),
    moodCalm: Color(0xFF1B7C83),
    moodNeutral: Color(0xFF6E7781),
    moodSad: Color(0xFF8250DF),
    scrim: Color(0x801F2328),
    pressed: Color(0x14818B98),
  );

  @override
  NvColors copyWith() => this;

  @override
  NvColors lerp(NvColors? other, double t) => t < 0.5 ? this : (other ?? this);
}

/// Fixed brand colours of the app icon and launch screen (same in both themes)
class NvBrand {
  static const Color canvas = Color(0xFF0D1117);
  static const Color chevron = Color(0xFF82AAFF);
  static const Color cursor = Color(0xFFF4F7FF);
}

/// Spacing scale (4-based)
class NvSpace {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Screen side gutter
  static const double gutter = 16;
}

/// One radius per nesting level
class NvRadius {
  /// Controls, boxes, cards
  static const double control = 6;

  /// Sheets and dialogs
  static const double sheet = 12;
  static const double pill = 999;
}

/// Control sizes (hit targets stay at 44 or more)
class NvSize {
  static const double control = 40;
  static const double controlLg = 44;
  static const double hit = 44;
}

class NvMotion {
  static const Duration micro = Duration(milliseconds: 120);
  static const Duration short = Duration(milliseconds: 220);
  static const Curve ease = Cubic(0.16, 1, 0.3, 1);

  /// Respect "remove animations" in the phone's accessibility settings
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.maybeDisableAnimationsOf(context) == true ? Duration.zero : d;
}

/// Type scale: system face, ratio about 1.125, one weight for headings.
class NvText {
  static const String? family = null; // Roboto on Android, SF Pro on iOS

  static const TextStyle display = TextStyle(
    fontFamily: family,
    fontSize: 24,
    height: 1.25,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );
  static const TextStyle title = TextStyle(
    fontFamily: family,
    fontSize: 20,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );
  static const TextStyle heading = TextStyle(
    fontFamily: family,
    fontSize: 17,
    height: 1.35,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle body = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle bodyStrong = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1.4,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle small = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle label = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle meta = TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 1.35,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle caption = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w400,
  );

  /// Code in entries (only where code is the material)
  static const TextStyle code = TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: ['Menlo', 'Roboto Mono'],
    fontSize: 14,
    height: 1.5,
  );

  /// Figures (streaks, counts): tabular numerals so they do not jitter
  static const TextStyle figure = TextStyle(
    fontFamily: family,
    fontSize: 22,
    height: 1.2,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

extension NvContext on BuildContext {
  NvColors get nv => Theme.of(this).extension<NvColors>()!;
}

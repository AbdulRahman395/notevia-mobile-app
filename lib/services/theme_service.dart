import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/tokens.dart';

/// Appearance: System, Light or Dark. Dark is the default, like the web app.
class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  static const String _modeKey = 'theme_mode';
  static const String _legacyKey = 'is_dark_mode';

  ThemeMode _mode = ThemeMode.dark;

  ThemeMode get themeMode => _mode;
  bool get isDarkMode => _mode == ThemeMode.dark;

  Future<void> loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_modeKey);
      if (saved != null) {
        _mode = ThemeMode.values.firstWhere(
          (m) => m.name == saved,
          orElse: () => ThemeMode.dark,
        );
      } else if (prefs.containsKey(_legacyKey)) {
        _mode = prefs.getBool(_legacyKey)! ? ThemeMode.dark : ThemeMode.light;
      }
    } catch (_) {
      _mode = ThemeMode.dark;
    }
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modeKey, mode.name);
    } catch (_) {}
  }

  Future<void> toggleTheme() =>
      setMode(isDarkMode ? ThemeMode.light : ThemeMode.dark);

  ThemeData get lightTheme => _build(NvColors.light, Brightness.light);
  ThemeData get darkTheme => _build(NvColors.dark, Brightness.dark);

  static ThemeData _build(NvColors c, Brightness b) {
    final scheme = ColorScheme(
      brightness: b,
      primary: c.accent,
      onPrimary: c.onAccent,
      secondary: c.primary,
      onSecondary: c.onPrimary,
      error: c.danger,
      onError: c.onPrimary,
      surface: c.bg,
      onSurface: c.text,
      onSurfaceVariant: c.muted,
      outline: c.line,
      outlineVariant: c.lineMuted,
      surfaceContainerLowest: c.bg,
      surfaceContainerLow: c.surface2,
      surfaceContainer: c.surface2,
      surfaceContainerHigh: c.surface2,
      surfaceContainerHighest: c.surface2,
      surfaceTint: Colors.transparent,
      scrim: c.scrim,
    );

    final text = TextTheme(
      headlineSmall: NvText.display.copyWith(color: c.fg),
      titleLarge: NvText.title.copyWith(color: c.fg),
      titleMedium: NvText.heading.copyWith(color: c.fg),
      titleSmall: NvText.label.copyWith(color: c.fg),
      bodyLarge: NvText.body.copyWith(color: c.text),
      bodyMedium: NvText.small.copyWith(color: c.text),
      bodySmall: NvText.meta.copyWith(color: c.muted),
      labelLarge: NvText.label.copyWith(color: c.fg),
      labelMedium: NvText.meta.copyWith(color: c.muted),
      labelSmall: NvText.caption.copyWith(color: c.muted),
    );

    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(NvRadius.control),
    );
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(NvRadius.control),
          borderSide: BorderSide(color: color, width: width),
        );

    final overlay = b == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      extensions: [c],
      textTheme: text,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      cardColor: c.surface,
      dividerColor: c.lineMuted,
      splashFactory: NoSplash.splashFactory,
      highlightColor: c.pressed,
      hoverColor: c.pressed,
      focusColor: c.accentSoft,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      dividerTheme: DividerThemeData(color: c.lineMuted, thickness: 1, space: 1),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.accent,
        selectionColor: c.accent.withValues(alpha: 0.32),
        selectionHandleColor: c.accent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.fg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 4,
        toolbarHeight: 56,
        titleTextStyle: NvText.heading.copyWith(color: c.fg),
        iconTheme: IconThemeData(color: c.fg, size: 22),
        actionsIconTheme: IconThemeData(color: c.fg, size: 22),
        systemOverlayStyle: overlay.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: c.bg,
        ),
      ),
      iconTheme: IconThemeData(color: c.muted, size: 20),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.fg,
          minimumSize: const Size(NvSize.hit, NvSize.hit),
          shape: controlShape,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.inset,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        hintStyle: NvText.body.copyWith(color: c.subtle),
        errorStyle: NvText.meta.copyWith(color: c.danger),
        border: border(c.line),
        enabledBorder: border(c.line),
        focusedBorder: border(c.accent, 2),
        errorBorder: border(c.danger),
        focusedErrorBorder: border(c.danger, 2),
        disabledBorder: border(c.lineMuted),
        prefixIconColor: c.muted,
        suffixIconColor: c.muted,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accent,
          textStyle: NvText.label,
          minimumSize: const Size(NvSize.hit, NvSize.hit),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: controlShape,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.lineMuted,
        circularTrackColor: Colors.transparent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onPrimary : c.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : c.surface2,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : c.lineStrong,
        ),
        thumbIcon: const WidgetStatePropertyAll(null),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accent : c.lineStrong,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface2,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.surface2,
        showDragHandle: true,
        dragHandleColor: c.lineStrong,
        dragHandleSize: const Size(36, 4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(NvRadius.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface2,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NvRadius.sheet),
          side: BorderSide(color: c.line),
        ),
        titleTextStyle: NvText.heading.copyWith(color: c.fg),
        contentTextStyle: NvText.small.copyWith(color: c.muted),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.surface2,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: c.surface2,
        headerForegroundColor: c.fg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NvRadius.sheet),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surface2,
        contentTextStyle: NvText.small.copyWith(color: c.fg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NvRadius.control),
          side: BorderSide(color: c.line),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        extendedTextStyle: NvText.label,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NvRadius.sheet),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface2,
        surfaceTintColor: Colors.transparent,
        textStyle: NvText.small.copyWith(color: c.fg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NvRadius.control),
          side: BorderSide(color: c.line),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

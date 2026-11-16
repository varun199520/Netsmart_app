import 'package:flutter/material.dart';

/// NetSmart web dark mode (GitHub-dark shell).
class NS {
  static const bg = Color(0xFF0D1117);
  static const surface = Color(0xFF161B22);
  static const hover = Color(0xFF1C2128);
  static const border = Color(0xFF30363D);
  static const borderMuted = Color(0xFF21262D);
  static const text = Color(0xFFE6EDF3);
  static const textSecondary = Color(0xFF8B949E);
  static const textDim = Color(0xFF484F58);
  static const success = Color(0xFF3FB950);
  static const danger = Color(0xFFF85149);
  static const warning = Color(0xFFD29922);
  static const accent = Color(0xFF58A6FF);
  static const purple = Color(0xFFA371F7);
  static const cyan = Color(0xFF39C5CF);
  static const orange = Color(0xFFF0883E);

  static const mono = TextStyle(fontFamily: 'Menlo', fontFamilyFallback: ['Courier', 'monospace']);

  /// Web sidebar section accents (`data-accent` in reimagined_base.css).
  static Color sectionAccent(String? key) => switch (key) {
        'ai' => accent,
        'network' => success,
        'security' => danger,
        'integr' => purple,
        'facility' => warning,
        'itops' => cyan,
        'content' => orange,
        'platform' => Color(0xFF6E7681),
        _ => textSecondary,
      };
}

/// The chatbot's "Nexus" palette, used only on chat screens.
class Nexus {
  static const bg = Color(0xFF0B0D17);
  static const bgDeep = Color(0xFF07090F);
  static const panel = Color(0xFF0F1220);
  static const surface = Color(0xFF131726);
  static const raised = Color(0xFF181E2E);
  static const border = Color(0xFF1A2138);
  static const borderStrong = Color(0xFF212C44);
  static const text = Color(0xFFE8EDF5);
  static const textSecondary = Color(0xFFA8B8CC);
  static const textDim = Color(0xFF556070);
  static const blue = Color(0xFF3B82F6);
  static const blueLight = Color(0xFF60A5FA);
  static const purple = Color(0xFF8B5CF6);
  static const cyan = Color(0xFF22D3EE);
  static const green = Color(0xFF10B981);
  static const red = Color(0xFFF43F5E);
  static const amber = Color(0xFFF59E0B);
  static const userBubble = LinearGradient(colors: [Color(0xFF1D4ED8), Color(0xFF6D28D9)]);
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: NS.accent,
    onPrimary: NS.bg,
    secondary: NS.purple,
    surface: NS.surface,
    onSurface: NS.text,
    error: NS.danger,
    outline: NS.border,
    outlineVariant: NS.borderMuted,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: Brightness.dark);
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: NS.border),
  );
  return base.copyWith(
    scaffoldBackgroundColor: NS.bg,
    canvasColor: NS.bg,
    dividerColor: NS.borderMuted,
    textTheme: base.textTheme.apply(bodyColor: NS.text, displayColor: NS.text),
    appBarTheme: const AppBarTheme(
      backgroundColor: NS.surface,
      foregroundColor: NS.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      shape: Border(bottom: BorderSide(color: NS.borderMuted)),
      titleTextStyle: TextStyle(color: NS.text, fontSize: 17, fontWeight: FontWeight.w600),
    ),
    cardTheme: CardThemeData(
      color: NS.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: NS.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: NS.bg,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      hintStyle: const TextStyle(color: NS.textDim),
      labelStyle: const TextStyle(color: NS.textSecondary),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: const BorderSide(color: NS.accent)),
      errorBorder: border.copyWith(borderSide: const BorderSide(color: NS.danger)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF238636),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: NS.text,
        side: const BorderSide(color: NS.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: NS.accent)),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: NS.surface,
      indicatorColor: NS.accent.withValues(alpha: 0.18),
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 11,
          color: s.contains(WidgetState.selected) ? NS.text : NS.textSecondary,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? NS.accent : NS.textSecondary),
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: NS.text,
      unselectedLabelColor: NS.textSecondary,
      indicatorColor: NS.accent,
      dividerColor: NS.borderMuted,
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: NS.surface,
      selectedColor: NS.accent.withValues(alpha: 0.2),
      side: const BorderSide(color: NS.border),
      labelStyle: const TextStyle(color: NS.text, fontSize: 12),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: NS.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: NS.border,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: NS.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: NS.border),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: NS.hover,
      contentTextStyle: TextStyle(color: NS.text),
      behavior: SnackBarBehavior.floating,
    ),
    listTileTheme: const ListTileThemeData(iconColor: NS.textSecondary, textColor: NS.text),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : NS.textSecondary),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? const Color(0xFF238636) : NS.borderMuted),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: NS.accent),
  );
}

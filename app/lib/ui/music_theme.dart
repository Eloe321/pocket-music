import 'package:flutter/material.dart';

const ink = Color(0xFF101B2D);
const panel = Color(0xFF1D2B42);
const copper = Color(0xFFEDAA7D);
const muted = Color(0xFF9DAFC6);

ThemeData musicTheme() {
  final colors =
      ColorScheme.fromSeed(
        seedColor: copper,
        brightness: Brightness.dark,
      ).copyWith(
        primary: copper,
        onPrimary: ink,
        surface: ink,
        surfaceContainer: panel,
        onSurface: const Color(0xFFF2F5F9),
        onSurfaceVariant: muted,
      );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colors,
    scaffoldBackgroundColor: ink,
    appBarTheme: const AppBarTheme(
      backgroundColor: ink,
      foregroundColor: Color(0xFFF2F5F9),
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: panel,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: ink,
      indicatorColor: panel,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: ink,
      showDragHandle: true,
    ),
    dividerTheme: DividerThemeData(color: muted.withValues(alpha: .15)),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -.7,
      ),
      titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5),
    ),
  );
}

String timeLabel(Duration value) {
  final seconds = value.inSeconds.clamp(0, 9999999);
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

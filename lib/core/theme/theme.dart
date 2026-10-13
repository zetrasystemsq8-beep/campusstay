import 'package:flutter/material.dart';
import 'tokens.dart';

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: CS.blue,
    primary: CS.blue,
    secondary: CS.teal,
    surface: CS.bg,
    error: CS.danger,
  );
  OutlineInputBorder border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(CS.rMd),
        borderSide: BorderSide(color: c),
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: CS.bg,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: CS.ink, height: 1.2),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: CS.ink),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CS.ink),
      bodyLarge: TextStyle(fontSize: 16, color: CS.ink, height: 1.4),
      bodyMedium: TextStyle(fontSize: 14, color: CS.ink, height: 1.4),
      bodySmall: TextStyle(fontSize: 12.5, color: CS.muted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: CS.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(CS.line),
      enabledBorder: border(CS.line),
      focusedBorder: border(CS.blue),
      errorBorder: border(CS.danger),
      focusedErrorBorder: border(CS.danger),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: CS.bg,
      indicatorColor: CS.blueSoft,
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: const BorderSide(color: CS.line),
      selectedColor: CS.blue,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      checkmarkColor: Colors.white,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CS.rMd)),
    ),
  );
}

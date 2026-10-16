import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryTeal = Color(0xFF00A884);
  static const Color darkBackground = Color(0xFF0B141A);
  static const Color darkSurface = Color(0xFF111B21);
  static const Color darkSurfaceVariant = Color(0xFF202C33);
  static const Color darkSenderBubble = Color(0xFF005C4B);
  static const Color darkReceiverBubble = Color(0xFF202C33);

  static const Color lightBackground = Color(0xFFF0F2F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSenderBubble = Color(0xFFD9FDD3);
  static const Color lightReceiverBubble = Color(0xFFFFFFFF);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: primaryTeal,
        onPrimary: Colors.white,
        surface: darkSurface,
        onSurface: Color(0xFFE9EDEF),
        surfaceContainerHighest: darkSurfaceVariant,
        outline: Color(0xFF8696A0),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: Color(0xFFE9EDEF),
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        color: darkSurface,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF222D34),
        thickness: 0.5,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceVariant,
        hintStyle: const TextStyle(color: Color(0xFF8696A0)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryTeal, width: 1.5),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme.light(
        primary: primaryTeal,
        onPrimary: Colors.white,
        surface: lightSurface,
        onSurface: Color(0xFF111B21),
        surfaceContainerHighest: Color(0xFFF0F2F5),
        outline: Color(0xFF667781),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF111B21),
        elevation: 0.5,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        color: lightSurface,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE9EDEF),
        thickness: 0.5,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF0F2F5),
        hintStyle: const TextStyle(color: Color(0xFF667781)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryTeal, width: 1.5),
        ),
      ),
    );
  }
}

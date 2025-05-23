import 'package:flutter/material.dart';

class AppTheme {
  // Modern and vibrant color palette
  static const Color primaryColor = Color(0xFF6C63FF);      // Vivid purple
  static const Color secondaryColor = Color(0xFF00D9F5);    // Bright cyan
  static const Color backgroundColor = Color(0xFFF0F3FF);   // Soft lavender
  static const Color accentColor = Color(0xFFFF6B6B);       // Coral pink
  static const Color textColor = Color(0xFF2D3436);         // Dark gray

  static ThemeData lightTheme = ThemeData(
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    colorScheme: ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      background: backgroundColor,
      tertiary: accentColor,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      elevation: 2,
      centerTitle: true,
      foregroundColor: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 3,
      ),
    ),
    cardTheme: CardTheme(
      color: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      shadowColor: primaryColor.withOpacity(0.3),
    ),
    textTheme: TextTheme(
      headlineMedium: const TextStyle(
        color: textColor,
        fontSize: 28,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      ),
      bodyLarge: TextStyle(
        color: textColor.withOpacity(0.9),
        fontSize: 16,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        color: textColor.withOpacity(0.8),
        fontSize: 14,
        height: 1.4,
      ),
    ),
  );
}
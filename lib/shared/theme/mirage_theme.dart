import 'package:flutter/material.dart';

abstract final class MirageColors {
  static const paper = Color(0xFFF7F5EF);
  static const ink = Color(0xFF181818);
  static const muted = Color(0xFF68665F);
  static const pink = Color(0xFFED2478);
  static const border = Color(0xFFDCDAD3);
  static const lavender = Color(0xFFE4DAF6);
  static const blue = Color(0xFFDFEBF3);
  static const lime = Color(0xFFD8F66D);
}

ThemeData mirageTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: MirageColors.paper,
  fontFamily: 'Inter',
  fontFamilyFallback: const ['MirageSymbols'],
  colorScheme: ColorScheme.fromSeed(
    seedColor: MirageColors.pink,
    primary: MirageColors.pink,
    surface: MirageColors.paper,
    onSurface: MirageColors.ink,
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontFamily: 'Lora',
      fontSize: 45,
      height: 1.08,
      fontWeight: FontWeight.w400,
      color: MirageColors.ink,
    ),
    headlineMedium: TextStyle(
      fontFamily: 'Lora',
      fontSize: 40,
      height: 1.08,
      fontWeight: FontWeight.w400,
      color: MirageColors.ink,
    ),
    bodyLarge: TextStyle(
      fontSize: 15,
      height: 1.4,
      letterSpacing: 0,
      color: MirageColors.muted,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      height: 1.4,
      letterSpacing: 0,
      color: MirageColors.ink,
    ),
    labelLarge: TextStyle(
      fontSize: 15,
      letterSpacing: 0,
      fontWeight: FontWeight.w600,
    ),
    labelSmall: TextStyle(
      fontSize: 12,
      height: 1.4,
      letterSpacing: 0,
      fontWeight: FontWeight.w600,
      color: MirageColors.ink,
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
    hintStyle: const TextStyle(
      fontFamily: 'Inter',
      fontSize: 14,
      color: MirageColors.muted,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: MirageColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: MirageColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: MirageColors.pink, width: 1.5),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: MirageColors.pink,
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: MirageColors.ink,
      disabledForegroundColor: MirageColors.muted,
      minimumSize: const Size(double.infinity, 52),
      side: const BorderSide(color: MirageColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: MirageColors.pink,
      textStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
);

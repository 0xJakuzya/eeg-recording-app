import 'package:flutter/material.dart';

// сentralized theme constants for EEG Recording App.
class AppTheme {
  AppTheme._();

  // backgrounds
  static const Color backgroundPrimary = Color(0xFF0D0D12);
  static const Color backgroundSecondary = Color(0xFF12121A);
  static const Color backgroundSurface = Color(0xFF1A1A24);

  // accents (dark blue → purple gradient)
  static const Color accentPrimary = Color(0xFF4F46E5);
  static const Color accentSecondary = Color(0xFF6366F1);
  static const Color accentTertiary = Color(0xFF7C3AED);
  static const Color accentViolet = Color(0xFFA78BFA);

  // glow/status colors
  static const Color statusConnected = Color(0xFF22D3EE); // cyan/teal
  static const Color statusRecording = Color(0xFFEF4444); // red
  static const Color statusPredictionReady = Color(0xFF22C55E); // green
  static const Color statusFailed = Color(0xFFEF4444);

  // text
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // border / divider
  static const Color borderSubtle = Color(0xFF27272A);
  static const Color gridLine = Color(0x14FFFFFF);

  // eeg channel colors 
  static const List<Color> eegChannelColors = [
    Color(0xFF22D3EE), 
    Color(0xFF2DD4BF), 
    Color(0xFF3B82F6), 
    Color(0xFF6366F1), 
    Color(0xFF8B5CF6), 
    Color(0xFFA78BFA), 
    Color(0xFF06B6D4), 
    Color(0xFF14B8A6), 
  ];

  // sleep stage colors (hypnogram)
  static const Color stageW = Color(0xFF64748B); 
  static const Color stageN1 = Color(0xFF7DD3FC); 
  static const Color stageN2 = Color(0xFF3B82F6); 
  static const Color stageN3 = Color(0xFF1D4ED8); 
  static const Color stageREM = Color(0xFF8B5CF6); 
  static Color getStageColor(String stage) {
    switch (stage.toUpperCase()) {
      case 'W':
      case 'WAKE':
        return stageW;
      case 'N1':
        return stageN1;
      case 'N2':
        return stageN2;
      case 'N3':
        return stageN3;
      case 'REM':
        return stageREM;
      default:
        return textSecondary;
    }
  }

  // Dark Theme
  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      primary: accentPrimary,
      secondary: accentSecondary,
      surface: backgroundSurface,
      error: statusFailed,
      onPrimary: textPrimary,
      onSecondary: textPrimary,
      onSurface: textPrimary,
      onError: textPrimary,
      outline: borderSubtle,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundPrimary,
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundSecondary,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: backgroundSurface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: backgroundSecondary,
        selectedItemColor: accentSecondary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: accentPrimary,
          foregroundColor: textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentSecondary,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentSecondary,
          side: const BorderSide(color: borderSubtle),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: backgroundSurface,
        contentTextStyle: const TextStyle(color: textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: backgroundSurface,
        titleTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: const TextStyle(color: textSecondary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: backgroundSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentPrimary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F5F8),
    );
  }
}

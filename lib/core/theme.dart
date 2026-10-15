import 'package:flutter/material.dart';

class AppColors {
  // Vibrant Brand Tokens
  static const primary = Color(0xFFD97706); // Rich Vibrant Terracotta
  static const terracotta = Color(0xFFD97706); // Rich Vibrant Terracotta
  static const terracottaVibrant = Color(0xFFEA580C);
  static const terracottaDark = Color(0xFFB45309);
  static const green = Color(0xFF059669); // Vibrant Emerald Green
  static const emerald = Color(0xFF10B981); // Radiant Emerald
  static const emeraldVibrant = Color(0xFF10B981);
  static const gold = Color(0xFFF59E0B); // Glowing Gold
  static const goldVibrant = Color(0xFFF59E0B);
  static const accentGold = Color(0xFFF59E0B);
  static const amber = Color(0xFFFBBF24); // Warm Amber
  static const navy = Color(0xFF1E2B45); // Deep Navy Blue
  static const ink = Color(0xFF0F172A); // Modern Dark Charcoal Ink
  static const canvas = Color(0xFFFAF8F5); // Crisp Warm Canvas
  static const mist = Color(0xFFF3F4F6); // Soft Cool Mist
  static const danger = Color(0xFFEF4444); // Vibrant Coral Red
  static const star = Color(0xFFFBBF24); // Golden Star
  static const warningBg = Color(0xFFFEF3C7); // Warm Gold Warning Bg

  static const olive = Color(0xFF856A00); // Rich Warm Olive
  static const driver = terracotta;

  // Dark Theme Palette Constants
  static const darkBg = Color(0xFF0F172A); // Midnight Slate
  static const darkCard = Color(0xFF1E293B); // Elevated Slate Surface
  static const darkCardElevated = Color(0xFF26334D);
  static const darkBorder = Color(0xFF334155); // Subtle Slate Border
  static const darkText = Color(0xFFF8FAFC); // High Contrast White
  static const darkSubtext = Color(0xFF94A3B8); // Cool Slate Secondary Text
  static const darkTextSecondary = Color(0xFF94A3B8);

  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEA580C), Color(0xFFF59E0B)],
  );

  static const navyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E2B45), Color(0xFF0F172A)],
  );

  static const darkSurfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E293B), Color(0xFF141E2F)],
  );

  // Dynamic Theme-Adaptive Color Getters
  static Color canvasColor(bool isDark) =>
      isDark ? const Color(0xFF0F172A) : const Color(0xFFFAF8F5);

  static Color cardColor(bool isDark) =>
      isDark ? const Color(0xFF1E293B) : Colors.white;

  static Color cardElevatedColor(bool isDark) =>
      isDark ? const Color(0xFF26334D) : const Color(0xFFF8FAFC);

  static Color borderColor(bool isDark) =>
      isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

  static Color textColor(bool isDark) =>
      isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

  static Color subtextColor(bool isDark) =>
      isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  static Color inputBgColor(bool isDark) =>
      isDark ? const Color(0xFF1E293B) : Colors.white;

  static Color pillBgColor(bool isDark) =>
      isDark ? const Color(0xFF334155) : const Color(0xFFEFEFEF);

  static Color navBgColor(bool isDark) =>
      isDark ? const Color(0xFF1E293B) : Colors.white;

  static Color navBorderColor(bool isDark) =>
      isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

  static Color navActiveColor(bool isDark) =>
      isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706);

  static Color navInactiveColor(bool isDark) =>
      isDark ? const Color(0xFF94A3B8) : const Color(0xFF8E8E93);

  static Color iconBgColor(bool isDark, Color lightBg) =>
      isDark ? lightBg.withValues(alpha: 0.18) : lightBg;
}

extension SakayThemeContextX on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
}

class SakayTheme {
  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.terracotta,
          primary: AppColors.terracotta,
          secondary: AppColors.green,
          surface: Colors.white,
          onSurface: AppColors.ink,
          outline: const Color(0xFFE2E8F0),
        ),
        scaffoldBackgroundColor: AppColors.canvas,
        cardColor: Colors.white,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.canvas,
          foregroundColor: AppColors.ink,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: AppColors.terracotta.withValues(alpha: .16),
          height: 68,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.terracotta, width: 1.8),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        chipTheme: const ChipThemeData(
          backgroundColor: AppColors.mist,
          side: BorderSide.none,
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFFE2E8F0)),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.terracotta,
          brightness: Brightness.dark,
          primary: AppColors.gold,
          secondary: AppColors.emerald,
          surface: AppColors.darkCard,
          onSurface: AppColors.darkText,
          outline: AppColors.darkBorder,
        ),
        scaffoldBackgroundColor: AppColors.darkBg,
        cardColor: AppColors.darkCard,
        canvasColor: AppColors.darkBg,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.darkBg,
          foregroundColor: AppColors.darkText,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: AppColors.darkCard,
          elevation: 3,
          shadowColor: Colors.black.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.darkBorder, width: 1),
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: AppColors.darkCard,
          indicatorColor: Color(0xFF334155),
          height: 68,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.darkCard,
          hintStyle:
              const TextStyle(color: AppColors.darkSubtext, fontSize: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.darkBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.darkBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.gold, width: 1.8),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.darkCard,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.darkCard,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        chipTheme: const ChipThemeData(
          backgroundColor: Color(0xFF26334D),
          side: BorderSide.none,
        ),
        dividerTheme: const DividerThemeData(color: AppColors.darkBorder),
      );
}

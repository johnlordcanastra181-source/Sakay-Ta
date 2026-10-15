import 'package:flutter/material.dart';

/// Design tokens and theme constants for the Sakay Ta Admin Web Dashboard.
class AdminTheme {
  // Brand Colors
  static const Color navy = Color(0xFF1E2B45);
  static const Color navyDark = Color(0xFF10192A);
  static const Color navyLight = Color(0xFF263350);
  static const Color navyBorder = Color(0xFF2E3D5C);

  static const Color terracotta = Color(0xFFC27A30);
  static const Color terracottaHover = Color(0xFFD98B3E);

  static const Color green = Color(0xFF2D6A4F);
  static const Color greenLight = Color(0xFF38855F);

  static const Color gold = Color(0xFFFFD600);
  static const Color slate = Color(0xFF8A9BBF);
  static const Color slateLight = Color(0xFFB0BFD8);

  // Background & Surfaces (Dark Slate/Navy Theme for Web Admin)
  static const Color bgPrimary = Color(0xFF0F1729);
  static const Color bgSecondary = Color(0xFF141E33);
  static const Color bgCard = Color(0xFF1A2740);
  static const Color bgCardHover = Color(0xFF1F2F4E);
  static const Color bgInput = Color(0xFF0E1827);

  // Borders & Dividers
  static const Color border = Color(0xFF2E3D5C);
  static const Color borderLight = Color(0x338A9BBF);

  // Text
  static const Color textPrimary = Color(0xFFE8EDF5);
  static const Color textSecondary = Color(0xFF8A9BBF);
  static const Color textMuted = Color(0xFF576685);

  // Semantic
  static const Color success = Color(0xFF2D6A4F);
  static const Color successText = Color(0xFF4ADE80);
  static const Color warning = Color(0xFFC27A30);
  static const Color warningText = Color(0xFFFCD34D);
  static const Color danger = Color(0xFFC0392B);
  static const Color dangerText = Color(0xFFF87171);
  static const Color info = Color(0xFF2980B9);
  static const Color infoText = Color(0xFF60A5FA);

  // Card Decoration
  static BoxDecoration cardDecoration({Color? borderColor, Color? color}) {
    return BoxDecoration(
      color: color ?? bgCard,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor ?? border, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // Input Decoration
  static InputDecoration inputDecoration({
    required String hintText,
    String? labelText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      hintStyle: const TextStyle(color: textMuted, fontSize: 13),
      labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
      filled: true,
      fillColor: bgInput,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: terracotta, width: 1.5),
      ),
    );
  }
}

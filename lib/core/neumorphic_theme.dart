import 'package:flutter/material.dart';

/// Centralized Design Tokens and Surface Builders for the
/// Sakay Ta Premium Enhanced Neumorphism Design System.
class NeumorphicColors {
  // --- Canvas / Backgrounds ---
  static Color canvas(bool isDark) =>
      isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F5F9);

  static Color surface(bool isDark) =>
      isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFD);

  static Color card(bool isDark) =>
      isDark ? const Color(0xFF1E293B) : Colors.white;

  static Color cardElevated(bool isDark) =>
      isDark ? const Color(0xFF26334D) : const Color(0xFFF0F4F9);

  static Color inset(bool isDark) =>
      isDark ? const Color(0xFF141E2F) : const Color(0xFFEBF0F7);

  static Color pill(bool isDark) =>
      isDark ? const Color(0xFF26334D) : const Color(0xFFE6ECF4);

  // --- Typography ---
  static Color textPrimary(bool isDark) =>
      isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B);

  static Color textSecondary(bool isDark) =>
      isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  static Color textMuted(bool isDark) =>
      isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

  static Color text(bool isDark) => textPrimary(isDark);
  static Color subtext(bool isDark) => textSecondary(isDark);

  // --- Borders ---
  static Color border(bool isDark) =>
      isDark ? const Color(0xFF2E3D56) : const Color(0xFFE2E8F0);

  static Color borderSubtle(bool isDark) =>
      isDark ? const Color(0xFF243045) : const Color(0xFFE8EEF5);

  // --- Brand Tokens ---
  static const Color brandPrimary = Color(0xFFEA580C); // Radiant Terracotta
  static const Color brandAmber = Color(0xFFF59E0B); // Amber Gold
  static const Color brandEmerald = Color(0xFF10B981); // Emerald
  static const Color brandNavy = Color(0xFF1E2B45); // Deep Navy

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEA580C), Color(0xFFF59E0B)],
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF223049), Color(0xFF1A2436)],
  );

  static const LinearGradient lightCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF5F8FC)],
  );

  // --- Shadows ---
  static Color shadowDark(bool isDark) => isDark
      ? const Color(0xFF070B14).withValues(alpha: 0.85)
      : const Color(0xFFA6B4C9).withValues(alpha: 0.40);

  static Color shadowLight(bool isDark) => isDark
      ? const Color(0xFF2E3D56).withValues(alpha: 0.45)
      : Colors.white.withValues(alpha: 0.95);
}

/// Static builders for Neumorphic decorations
class NeumorphicDecorations {
  static const List<BoxShadow> _cachedSubtleDark = [
    BoxShadow(
      color: Color(0x59070B14),
      offset: Offset(2.0, 2.0),
      blurRadius: 5.0,
    ),
    BoxShadow(
      color: Color(0x402E3D56),
      offset: Offset(-2.0, -2.0),
      blurRadius: 5.0,
    ),
  ];

  static const List<BoxShadow> _cachedSubtleLight = [
    BoxShadow(
      color: Color(0x2EA6B4C9),
      offset: Offset(2.0, 2.0),
      blurRadius: 5.0,
    ),
    BoxShadow(
      color: Color(0xA6FFFFFF),
      offset: Offset(-2.0, -2.0),
      blurRadius: 5.0,
    ),
  ];

  static const List<BoxShadow> _cachedRaisedDark = [
    BoxShadow(
      color: Color(0xD9070B14),
      offset: Offset(3.0, 3.0),
      blurRadius: 6.0,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x732E3D56),
      offset: Offset(-2.5, -2.5),
      blurRadius: 6.0,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> _cachedRaisedLight = [
    BoxShadow(
      color: Color(0x66A6B4C9),
      offset: Offset(3.0, 3.0),
      blurRadius: 6.0,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0xF2FFFFFF),
      offset: Offset(-2.5, -2.5),
      blurRadius: 6.0,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> _cachedInsetDark = [
    BoxShadow(
      color: Color(0x73070B14),
      offset: Offset(1.5, 1.5),
      blurRadius: 3.0,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> _cachedInsetLight = [
    BoxShadow(
      color: Color(0x38A6B4C9),
      offset: Offset(1.5, 1.5),
      blurRadius: 3.0,
      spreadRadius: 0,
    ),
  ];

  static final Border _defaultRaisedBorderDark = Border.all(
    color: const Color(0x592E3D56),
    width: 1,
  );

  static final Border _defaultRaisedBorderLight = Border.all(
    color: const Color(0xBFFFFFFF),
    width: 1,
  );

  /// Subtle dual directional shadows for soft elements and avatars
  static List<BoxShadow> subtleShadows(bool isDark,
      {double distance = 2.0, double blur = 6.0}) {
    if (distance == 2.0 && blur == 6.0) {
      return isDark ? _cachedSubtleDark : _cachedSubtleLight;
    }
    return [
      BoxShadow(
        color: NeumorphicColors.shadowDark(isDark)
            .withValues(alpha: isDark ? 0.35 : 0.18),
        offset: Offset(distance, distance),
        blurRadius: blur,
      ),
      BoxShadow(
        color: NeumorphicColors.shadowLight(isDark)
            .withValues(alpha: isDark ? 0.25 : 0.65),
        offset: Offset(-distance, -distance),
        blurRadius: blur,
      ),
    ];
  }

  /// Raised surface with dual opposing directional shadows
  static BoxDecoration raised({
    required bool isDark,
    double radius = 16.0,
    double? borderRadius,
    double distance = 4.0,
    double blur = 6.0,
    Color? color,
    Border? border,
    Gradient? gradient,
    BoxShape shape = BoxShape.rectangle,
  }) {
    final baseColor = color ?? NeumorphicColors.surface(isDark);
    final effectiveRadius = borderRadius ?? radius;
    final boxBorderRadius =
        shape == BoxShape.circle ? null : BorderRadius.circular(effectiveRadius);
    final useCachedShadows = distance == 4.0 && blur == 6.0;

    return BoxDecoration(
      color: gradient == null ? baseColor : null,
      gradient: gradient,
      shape: shape,
      borderRadius: boxBorderRadius,
      border: border ??
          (isDark ? _defaultRaisedBorderDark : _defaultRaisedBorderLight),
      boxShadow: useCachedShadows
          ? (isDark ? _cachedRaisedDark : _cachedRaisedLight)
          : [
              BoxShadow(
                color: NeumorphicColors.shadowDark(isDark),
                offset: Offset(distance, distance),
                blurRadius: blur,
                spreadRadius: 0,
              ),
              BoxShadow(
                color: NeumorphicColors.shadowLight(isDark),
                offset: Offset(-distance, -distance),
                blurRadius: blur,
                spreadRadius: 0,
              ),
            ],
    );
  }

  /// Inset surface for text fields, search bars, and sunken wells
  static BoxDecoration inset({
    required bool isDark,
    double radius = 14.0,
    double? borderRadius,
    Color? color,
    Color? borderColor,
    double borderWidth = 1.0,
  }) {
    final baseColor = color ?? NeumorphicColors.inset(isDark);
    final effectiveRadius = borderRadius ?? radius;

    return BoxDecoration(
      color: baseColor,
      borderRadius: BorderRadius.circular(effectiveRadius),
      border: Border.all(
        color: borderColor ??
            (isDark ? const Color(0xFF26334D) : const Color(0xFFDDE3ED)),
        width: borderWidth,
      ),
      boxShadow: isDark ? _cachedInsetDark : _cachedInsetLight,
    );
  }

  /// Accent-colored raised surface with ambient glow for primary CTA buttons
  static BoxDecoration accentRaised({
    required Color color,
    Gradient? gradient,
    double radius = 14.0,
    double elevation = 4.0,
  }) {
    return BoxDecoration(
      color: gradient == null ? color : null,
      gradient: gradient ?? NeumorphicColors.brandGradient,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.38),
          offset: Offset(0, elevation),
          blurRadius: elevation * 2.5,
          spreadRadius: 0,
        ),
      ],
    );
  }

  /// Soft pill surface for badges and selectors
  static BoxDecoration pill({
    required bool isDark,
    bool isSelected = false,
    Color? activeColor,
    Color? color,
    Border? border,
  }) {
    if (isSelected) {
      final active = activeColor ?? NeumorphicColors.brandPrimary;
      return BoxDecoration(
        color: active,
        borderRadius: BorderRadius.circular(24),
        border: border,
        boxShadow: [
          BoxShadow(
            color: active.withValues(alpha: 0.35),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      );
    }
    return BoxDecoration(
      color: color ?? NeumorphicColors.pill(isDark),
      borderRadius: BorderRadius.circular(24),
      border: border ??
          Border.all(
            color: isDark ? const Color(0xFF26334D) : const Color(0xFFDDE3ED),
            width: 1,
          ),
    );
  }
}


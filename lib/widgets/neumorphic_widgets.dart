import 'package:flutter/material.dart';
import '../core/neumorphic_theme.dart';

/// Reusable tactile Neumorphic Card with optional tap animation.
class NeumorphicCard extends StatefulWidget {
  const NeumorphicCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    double radius = 16.0,
    double? borderRadius,
    this.distance = 4.0,
    this.blur = 6.0,
    this.color,
    this.gradient,
    this.border,
    this.onTap,
  }) : radius = borderRadius ?? radius;

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final double distance;
  final double blur;
  final Color? color;
  final Gradient? gradient;
  final Border? border;
  final VoidCallback? onTap;

  @override
  State<NeumorphicCard> createState() => _NeumorphicCardState();
}

class _NeumorphicCardState extends State<NeumorphicCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget content = Container(
      padding: widget.padding,
      decoration: NeumorphicDecorations.raised(
        isDark: isDark,
        radius: widget.radius,
        distance: _isPressed ? widget.distance * 0.4 : widget.distance,
        blur: _isPressed ? widget.blur * 0.5 : widget.blur,
        color: widget.color,
        gradient: widget.gradient,
        border: widget.border,
      ),
      child: widget.child,
    );

    if (widget.margin != null) {
      content = Padding(padding: widget.margin!, child: content);
    }

    if (widget.onTap != null) {
      return RepaintBoundary(
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _isPressed ? 0.985 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            child: content,
          ),
        ),
      );
    }

    return RepaintBoundary(child: content);
  }
}

/// Tactile Primary Neumorphic Button with spring compression and loading state.
class NeumorphicButton extends StatefulWidget {
  const NeumorphicButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isSecondary = false,
    this.accentColor,
    this.height = 52.0,
    this.radius = 14.0,
    this.width = double.infinity,
  });

  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isSecondary;
  final Color? accentColor;
  final double height;
  final double radius;
  final double width;

  @override
  State<NeumorphicButton> createState() => _NeumorphicButtonState();
}

class _NeumorphicButtonState extends State<NeumorphicButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = widget.accentColor ?? NeumorphicColors.brandPrimary;
    final isDisabled = widget.onPressed == null || widget.isLoading;

    Decoration decoration;
    Color textColor;

    if (widget.isSecondary) {
      decoration = NeumorphicDecorations.raised(
        isDark: isDark,
        radius: widget.radius,
        distance: _isPressed ? 1.5 : 3.5,
        blur: _isPressed ? 4.0 : 8.0,
      );
      textColor = NeumorphicColors.textPrimary(isDark);
    } else {
      decoration = NeumorphicDecorations.accentRaised(
        color: isDisabled ? Colors.grey.shade400 : primaryColor,
        gradient: isDisabled
            ? null
            : LinearGradient(
                colors: [
                  primaryColor,
                  widget.accentColor ?? const Color(0xFFF59E0B),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        radius: widget.radius,
        elevation: _isPressed ? 1.5 : 4.0,
      );
      textColor = Colors.white;
    }

    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => setState(() => _isPressed = true),
      onTapUp: isDisabled ? null : (_) => setState(() => _isPressed = false),
      onTapCancel:
          isDisabled ? null : () => setState(() => _isPressed = false),
      onTap: isDisabled ? null : widget.onPressed,
      child: AnimatedScale(
        scale: _isPressed ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: decoration,
          alignment: Alignment.center,
          child: widget.isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(textColor),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 19, color: textColor),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        widget.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Floating circular or rounded Neumorphic Icon Button for map & controls.
class NeumorphicIconButton extends StatefulWidget {
  const NeumorphicIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 44.0,
    this.iconSize = 20.0,
    this.iconColor,
    this.tooltip,
    this.isCircle = true,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final Color? iconColor;
  final String? tooltip;
  final bool isCircle;

  @override
  State<NeumorphicIconButton> createState() => _NeumorphicIconButtonState();
}

class _NeumorphicIconButtonState extends State<NeumorphicIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = widget.iconColor ??
        (isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B));

    Widget button = GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: NeumorphicDecorations.raised(
            isDark: isDark,
            radius: widget.size / 2,
            shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
            distance: _isPressed ? 1.5 : 3.5,
            blur: _isPressed ? 4.0 : 8.0,
          ),
          alignment: Alignment.center,
          child: Icon(widget.icon, size: widget.iconSize, color: color),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: button);
    }
    return button;
  }
}

/// Recessed Inset Text Field with subtle depth and clean focus state.
class NeumorphicTextField extends StatefulWidget {
  const NeumorphicTextField({
    super.key,
    this.label,
    required this.hintText,
    this.controller,
    this.focusNode,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.readOnly = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.onTap,
    this.onChanged,
    this.maxLines = 1,
    this.initialValue,
    double radius = 14.0,
    double? borderRadius,
  }) : radius = borderRadius ?? radius;

  final String? label;
  final String hintText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final bool readOnly;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final String? initialValue;
  final double radius;

  @override
  State<NeumorphicTextField> createState() => _NeumorphicTextFieldState();
}

class _NeumorphicTextFieldState extends State<NeumorphicTextField> {
  FocusNode? _internalFocusNode;
  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _effectiveFocusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(NeumorphicTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      (oldWidget.focusNode ?? _internalFocusNode)
          ?.removeListener(_handleFocusChange);
      _effectiveFocusNode.addListener(_handleFocusChange);
    }
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() => _isFocused = _effectiveFocusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_handleFocusChange);
    _internalFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              widget.label!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: NeumorphicColors.textSecondary(isDark),
              ),
            ),
          ),
        ],
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          clipBehavior: Clip.antiAlias,
          decoration: NeumorphicDecorations.inset(
            isDark: isDark,
            radius: widget.radius,
            borderColor: _isFocused
                ? NeumorphicColors.brandPrimary
                : (isDark ? const Color(0xFF26334D) : const Color(0xFFDDE3ED)),
            borderWidth: _isFocused ? 1.6 : 1.0,
          ),
          child: TextFormField(
            focusNode: _effectiveFocusNode,
            controller: widget.controller,
            initialValue: widget.initialValue,
            obscureText: widget.obscureText,
            readOnly: widget.readOnly,
            onTap: widget.onTap,
            onChanged: widget.onChanged,
            validator: widget.validator,
            keyboardType: widget.keyboardType,
            textCapitalization: widget.textCapitalization,
            maxLines: widget.maxLines,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: NeumorphicColors.textPrimary(isDark),
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              fillColor: Colors.transparent,
              hintText: widget.hintText,
              hintStyle: TextStyle(
                color: NeumorphicColors.textMuted(isDark),
                fontSize: 14,
              ),
              prefixIcon: widget.prefixIcon,
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 44, minHeight: 44),
              suffixIcon: widget.suffixIcon,
              suffixIconConstraints:
                  const BoxConstraints(minWidth: 44, minHeight: 44),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}

/// Neumorphic Stat / Metric Card with large readable numbers.
class NeumorphicStatCard extends StatelessWidget {
  const NeumorphicStatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.accentColor,
    this.subtitle,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? accentColor;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = accentColor ?? NeumorphicColors.brandPrimary;

    return NeumorphicCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: NeumorphicColors.textSecondary(isDark),
                ),
              ),
              if (icon != null) Icon(icon, size: 16, color: accent),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: NeumorphicColors.textPrimary(isDark),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 11,
                color: NeumorphicColors.textMuted(isDark),
              ),
            ),
          ],
        ],
      ),
    );
  }
}


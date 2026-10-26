import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/neumorphic_theme.dart';
import '../core/theme.dart';
import 'neumorphic_widgets.dart';
import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import 'user_avatar.dart';

class SakayTaLogoIcon extends StatelessWidget {
  const SakayTaLogoIcon({
    super.key,
    this.size = 32,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF1E2B45), // Navy Blue circle matching logo picture
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Darker Pin backdrop layer matching logo picture
          Positioned(
            bottom: size * 0.08,
            child: Icon(
              Icons.location_on_rounded,
              size: size * 0.72,
              color: const Color(0xFF142036),
            ),
          ),
          // Yellow Tricycle Icon matching logo picture
          Icon(
            Icons.electric_rickshaw_rounded,
            size: size * 0.58,
            color: const Color(0xFFFFD600),
          ),
        ],
      ),
    );
  }
}

class Brand extends StatelessWidget {
  const Brand({super.key, this.dark = false, this.size = 32});
  final bool dark;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SakayTaLogoIcon(size: size),
          const SizedBox(width: 8),
          Text(
            'Sakay Ta',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: size * 0.55,
              color: dark ? Colors.white : const Color(0xFF1E1E1E),
              letterSpacing: -0.3,
            ),
          ),
        ],
      );
}

class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    this.size = 34,
    this.name,
    this.color,
    this.iconData,
    this.photoUrl,
  });
  final double size;
  final String? name;
  final Color? color;
  final IconData? iconData;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final base = color ?? AppColors.green;
    String? resolvedPhoto = photoUrl;
    String? resolvedName = name;

    if (resolvedPhoto == null || resolvedPhoto.trim().isEmpty) {
      try {
        final app = context.watch<AppState?>();
        resolvedPhoto =
            app?.currentUser?.profilePhotoUrl ?? app?.driverProfile?.docProfile;
        resolvedName ??= app?.currentUser?.fullName;
      } catch (e) {
        debugPrint('Common widget non-fatal note: $e');
      }
    }

    final imageProvider = getUserAvatarImageProvider(resolvedPhoto);
    if (imageProvider != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: ClipOval(
          child: Image(
            image: imageProvider,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallback(base, resolvedName),
          ),
        ),
      );
    }

    return _buildFallback(base, resolvedName);
  }

  Widget _buildFallback(Color base, String? resolvedName) {
    final hasName = resolvedName != null && resolvedName.trim().isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: base.withValues(alpha: .16),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: hasName
          ? Center(
              child: Text(
                resolvedName.trim()[0].toUpperCase(),
                style: TextStyle(
                  color: base,
                  fontWeight: FontWeight.w800,
                  fontSize: size * .4,
                ),
              ),
            )
          : Icon(iconData ?? Icons.person_rounded,
              size: size * .6, color: base),
    );
  }
}

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.radius = 16.0,
  });
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = color ?? NeumorphicColors.surface(isDark);

    Widget box = Container(
      decoration: NeumorphicDecorations.raised(
        isDark: isDark,
        color: cardBg,
        radius: radius,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    return box;
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.color,
  });
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: NeumorphicButton(
        text: label,
        icon: icon,
        accentColor: color ?? NeumorphicColors.brandPrimary,
        onPressed: onTap,
      ),
    );
  }
}

class CustomButton extends StatefulWidget {
  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.height = 54.0,
    this.borderRadius = 14.0,
    this.fontSize = 15.0,
    this.fontWeight = FontWeight.w700,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final double height;
  final double borderRadius;
  final double fontSize;
  final FontWeight fontWeight;

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final primary = widget.backgroundColor ?? NeumorphicColors.brandPrimary;
    final isDisabled = widget.onPressed == null || widget.isLoading;

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
          width: double.infinity,
          height: widget.height,
          decoration: NeumorphicDecorations.accentRaised(
            color: isDisabled ? Colors.grey.shade400 : primary,
            gradient: isDisabled
                ? null
                : LinearGradient(
                    colors: [
                      primary,
                      widget.backgroundColor ?? const Color(0xFFF59E0B),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            radius: widget.borderRadius,
            elevation: _isPressed ? 1.5 : 4.0,
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  widget.text,
                  style: TextStyle(
                    fontSize: widget.fontSize,
                    fontWeight: widget.fontWeight,
                    color: widget.textColor ?? Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }
}

class CustomTextField extends StatefulWidget {
  const CustomTextField({
    super.key,
    required this.label,
    required this.hintText,
    required this.prefixIcon,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
    this.validator,
    this.textCapitalization = TextCapitalization.none,
    this.onTap,
    this.readOnly = false,
    this.maxLines = 1,
    this.initialValue,
    this.onChanged,
  });

  final String label;
  final String hintText;
  final IconData prefixIcon;
  final bool obscureText;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;
  final VoidCallback? onTap;
  final bool readOnly;
  final int maxLines;
  final String? initialValue;
  final ValueChanged<String>? onChanged;

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: NeumorphicColors.textSecondary(isDark),
            ),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: NeumorphicDecorations.inset(
            isDark: isDark,
            radius: 14.0,
            borderColor: _isFocused
                ? NeumorphicColors.brandPrimary
                : (isDark ? const Color(0xFF26334D) : const Color(0xFFDDE3ED)),
            borderWidth: _isFocused ? 1.6 : 1.0,
          ),
          child: TextFormField(
            focusNode: _focusNode,
            controller: widget.controller,
            initialValue: widget.initialValue,
            obscureText: widget.obscureText,
            readOnly: widget.readOnly,
            onTap: widget.onTap,
            maxLines: widget.maxLines,
            keyboardType: widget.keyboardType,
            textCapitalization: widget.textCapitalization,
            validator: widget.validator,
            onChanged: widget.onChanged,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: NeumorphicColors.textPrimary(isDark),
            ),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(
                color: NeumorphicColors.textMuted(isDark),
                fontSize: 14,
              ),
              prefixIcon: Icon(
                widget.prefixIcon,
                size: 20,
                color: _isFocused
                    ? NeumorphicColors.brandPrimary
                    : NeumorphicColors.textSecondary(isDark),
              ),
              suffixIcon: widget.suffixIcon,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}

class AppTop extends StatelessWidget {
  const AppTop({super.key, required this.title, this.back, this.action});
  final String title;
  final VoidCallback? back;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
        child: Row(
          children: [
            if (back != null)
              IconButton(
                onPressed: back,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              ),
            Expanded(
              child: Text(
                title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            action ?? const SizedBox.shrink(),
          ],
        ),
      );
}

class Field extends StatelessWidget {
  const Field({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.controller,
    this.keyboardType,
    this.suffix,
    this.validator,
    this.textCapitalization = TextCapitalization.none,
    this.onTap,
    this.readOnly = false,
    this.maxLines = 1,
    this.initialValue,
  });
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;
  final VoidCallback? onTap;
  final bool readOnly;
  final int maxLines;
  final String? initialValue;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          TextFormField(
            controller: controller,
            initialValue: initialValue,
            obscureText: obscure,
            readOnly: readOnly,
            onTap: onTap,
            maxLines: maxLines,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            validator: validator,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 19),
              hintText: hint,
              suffixIcon: obscure
                  ? const Icon(Icons.visibility_off_outlined, size: 19)
                  : suffix,
            ),
          ),
        ],
      );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            if (action != null)
              InkWell(
                onTap: onAction,
                child: Text(
                  '$action  ›',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.terracotta),
                ),
              ),
          ],
        ),
      );
}

class CircleIcon extends StatelessWidget {
  const CircleIcon(
      {super.key, required this.icon, this.color = AppColors.gold});
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: 18,
        backgroundColor: color.withValues(alpha: .2),
        child: Icon(icon, color: color, size: 19),
      );
}

class StatCard extends StatelessWidget {
  const StatCard(
      {super.key, required this.value, required this.label, this.color});
  final String value, label;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Panel(
      padding: const EdgeInsets.all(13),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color ?? NeumorphicColors.brandPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: NeumorphicColors.textSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.action,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String? body;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.gold.withValues(alpha: .8)),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            if (body != null) ...[
              const SizedBox(height: 5),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: 220,
                child: PrimaryButton(label: action!, onTap: onAction ?? () {}),
              ),
            ],
          ],
        ),
      );
}

class ConfirmDialog {
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String body,
    String? confirmLabel,
    bool danger = false,
  }) async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel ?? l10n.commonConfirm),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class InfoSnack {
  static void show(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.green,
        ),
      );
  }
}

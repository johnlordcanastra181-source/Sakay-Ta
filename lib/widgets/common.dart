import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
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
      } catch (_) {}
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
  });
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: color ??
            (Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E2724)
                : Colors.white),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(padding: padding, child: child),
        ),
      );
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
  Widget build(BuildContext context) => SizedBox(
        height: 50,
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: color ?? AppColors.terracotta,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: onTap,
          icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
          label:
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      );
}

class CustomButton extends StatelessWidget {
  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.height = 56.0,
    this.borderRadius = 12.0,
    this.fontSize = 16.0,
    this.fontWeight = FontWeight.w600,
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
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? AppColors.terracotta,
          foregroundColor: textColor ?? Colors.white,
          disabledBackgroundColor: Colors.grey.shade400,
          disabledForegroundColor: Colors.white70,
          elevation: 2,
          shadowColor: AppColors.terracotta.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                text,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: fontWeight,
                  color: textColor ?? Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
      ),
    );
  }
}

class CustomTextField extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      obscureText: obscureText,
      readOnly: readOnly,
      onTap: onTap,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: validator,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 15, color: AppColors.ink),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        prefixIcon: Icon(prefixIcon, size: 20, color: AppColors.terracotta),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD8CCBA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD8CCBA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.terracotta, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.8),
        ),
        errorStyle: const TextStyle(
          color: AppColors.danger,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
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
  Widget build(BuildContext context) => Panel(
        padding: const EdgeInsets.all(13),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color ?? AppColors.terracotta,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      );
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

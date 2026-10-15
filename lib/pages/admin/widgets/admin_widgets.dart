import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../admin_theme.dart';

/// Keeps failed or unavailable data sources actionable instead of spinning forever.
class AdminDataStreamBuilder<T> extends StatefulWidget {
  const AdminDataStreamBuilder({
    super.key,
    this.stream,
    this.streamFactory,
    this.section = 'unknown',
    required this.builder,
    this.initialData,
  }) : assert(stream != null || streamFactory != null);
  final Stream<T>? stream;
  final Stream<T> Function()? streamFactory;
  final String section;
  final AsyncWidgetBuilder<T> builder;
  final T? initialData;

  @override
  State<AdminDataStreamBuilder<T>> createState() =>
      _AdminDataStreamBuilderState<T>();
}

class _AdminDataStreamBuilderState<T> extends State<AdminDataStreamBuilder<T>> {
  Stream<T>? _stream;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void didUpdateWidget(covariant AdminDataStreamBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.streamFactory == null && oldWidget.stream != widget.stream) {
      _connect();
    }
  }

  void _connect() {
    Stream<T>? source;
    try {
      source = widget.streamFactory?.call() ?? widget.stream;
    } catch (error, stackTrace) {
      source = Stream<T>.error(error, stackTrace);
    }
    if (source == null) {
      _stream = null;
      return;
    }
    final activeSource = source;
    debugPrint('[ADMIN DATA] section=${widget.section} stage=stream_connect');
    _stream = Stream<T>.multi((controller) {
      final timer = Timer(const Duration(seconds: 15), () {
        controller
            .addError(TimeoutException('The data source did not respond.'));
      });
      final subscription = activeSource.listen((value) {
        timer.cancel();
        debugPrint(
            '[ADMIN DATA] section=${widget.section} stage=stream_success');
        controller.add(value);
      }, onError: (Object error, StackTrace stack) {
        timer.cancel();
        if (error is PostgrestException) {
          debugPrint('[ADMIN POSTGREST ERROR] section=${widget.section} '
              'code=${error.code} message=${error.message} '
              'details=${error.details} hint=${error.hint}');
        } else {
          debugPrint('[ADMIN ERROR] section=${widget.section} '
              'type=${error.runtimeType} message=$error');
        }
        debugPrintStack(stackTrace: stack);
        controller.addError(error, stack);
      }, onDone: () {
        timer.cancel();
        controller.close();
      });
      controller.onCancel = () {
        timer.cancel();
        return subscription.cancel();
      };
    });
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<T>(
        initialData: widget.initialData,
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined,
                        color: AdminTheme.textMuted),
                    const SizedBox(height: 8),
                    Text(
                      'Unable to load this data right now.\nPlease try again.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                        onPressed: () => setState(_connect),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry')),
                  ],
                ));
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          return widget.builder(context, snapshot);
        },
      );
}

/// Stat card for overview metrics.
class AdminStatCard extends StatelessWidget {
  const AdminStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.subtitle,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AdminTheme.cardDecoration().copyWith(
          border: Border(
            top: BorderSide(color: accentColor, width: 3),
            left: const BorderSide(color: AdminTheme.border),
            right: const BorderSide(color: AdminTheme.border),
            bottom: const BorderSide(color: AdminTheme.border),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accentColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      color: AdminTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: AdminTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: AdminTheme.textMuted,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Status chip badge for tables and cards.
class AdminStatusBadge extends StatelessWidget {
  const AdminStatusBadge({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    Color bg;
    Color fg;
    String label = status.toUpperCase();

    if (s == 'active' ||
        s == 'approved' ||
        s == 'completed' ||
        s == 'paid' ||
        s == 'resolved') {
      bg = AdminTheme.green.withValues(alpha: 0.18);
      fg = AdminTheme.successText;
      if (s == 'active') label = 'Active';
      if (s == 'approved') label = 'Approved';
      if (s == 'completed') label = 'Completed';
      if (s == 'paid') label = 'Paid';
      if (s == 'resolved') label = 'Resolved';
    } else if (s == 'pending' ||
        s == 'searching' ||
        s == 'under_investigation' ||
        s == 'queued') {
      bg = AdminTheme.warning.withValues(alpha: 0.18);
      fg = AdminTheme.warningText;
      if (s == 'pending') label = 'Pending';
      if (s == 'searching') label = 'Searching';
      if (s == 'under_investigation') label = 'Investigating';
    } else if (s == 'suspended' ||
        s == 'rejected' ||
        s == 'deactivated' ||
        s == 'failed' ||
        s == 'restricted') {
      bg = AdminTheme.danger.withValues(alpha: 0.18);
      fg = AdminTheme.dangerText;
      if (s == 'suspended') label = 'Suspended';
      if (s == 'rejected') label = 'Rejected';
      if (s == 'deactivated') label = 'Deactivated';
      if (s == 'restricted') label = 'Restricted';
    } else if (s == 'started' ||
        s == 'accepted' ||
        s == 'arrived' ||
        s == 'online') {
      bg = AdminTheme.info.withValues(alpha: 0.18);
      fg = AdminTheme.infoText;
      if (s == 'started') label = 'In Progress';
      if (s == 'accepted') label = 'Accepted';
      if (s == 'online') label = 'Online';
    } else {
      bg = AdminTheme.slate.withValues(alpha: 0.15);
      fg = AdminTheme.slateLight;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Section header for dashboard views.
class AdminSectionHeader extends StatelessWidget {
  const AdminSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AdminTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AdminTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actions != null) ...[
            const SizedBox(width: 16),
            Wrap(spacing: 10, runSpacing: 8, children: actions!),
          ],
        ],
      ),
    );
  }
}

/// Reusable empty state view.
class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AdminTheme.navyLight.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: AdminTheme.slate),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: AdminTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AdminTheme.textMuted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Confirmation Dialog helper.
Future<bool?> showAdminConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmText = 'Confirm',
  String cancelText = 'Cancel',
  Color confirmColor = AdminTheme.danger,
  IconData icon = Icons.warning_amber_rounded,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AdminTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AdminTheme.border),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: confirmColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: confirmColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AdminTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: const TextStyle(
          color: AdminTheme.textSecondary,
          fontSize: 13,
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child:
              Text(cancelText, style: const TextStyle(color: AdminTheme.slate)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: Text(confirmText,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}

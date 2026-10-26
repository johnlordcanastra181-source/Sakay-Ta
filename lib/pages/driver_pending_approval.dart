import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/neumorphic_theme.dart';
import '../core/theme.dart';
import '../main.dart';
import '../state/app_state.dart';
import '../widgets/neumorphic_widgets.dart';

/// Shown only after the database confirms a driver's pending application.
class DriverPendingApproval extends StatefulWidget {
  const DriverPendingApproval({super.key, required this.onNavigate});

  final Function(AppScreen) onNavigate;

  @override
  State<DriverPendingApproval> createState() => _DriverPendingApprovalState();
}

class _DriverPendingApprovalState extends State<DriverPendingApproval> {
  Timer? _statusTimer;
  bool _isRefreshing = false;
  bool _isNavigatingToDashboard = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final app = context.read<AppState>();
      if (app.pendingDriverApplicationId != null) {
        app.refreshDriverApplicationStatus().then((_) {
          if (mounted) _checkApprovalAndNavigate();
        });
        _statusTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
          if (mounted) {
            await context.read<AppState>().refreshDriverApplicationStatus();
            if (mounted) _checkApprovalAndNavigate();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkApprovalAndNavigate() async {
    final app = context.read<AppState>();
    final status = app.pendingDriverApplicationStatus;
    if (status == 'active' || status == 'approved') {
      _statusTimer?.cancel();
      final initialized = await app.initializeApprovedDriverSession();
      if (!mounted) return;
      if (initialized && app.currentUser?.isDriver == true) {
        widget.onNavigate(AppScreen.driverHome);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your session could not be verified. Please sign in to access your dashboard.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        widget.onNavigate(AppScreen.login);
      }
    }
  }

  Future<void> _refreshStatus() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await context.read<AppState>().refreshDriverApplicationStatus();
    if (mounted) {
      setState(() => _isRefreshing = false);
      await _checkApprovalAndNavigate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final status = app.pendingDriverApplicationStatus;
    final hasReceipt = app.pendingDriverApplicationId != null;
    final isRejected = status == 'rejected';
    final isApproved = status == 'active' || status == 'approved';
    final title = switch (status) {
      'rejected' => 'Application rejected',
      'awaiting_activation' => 'Application approved — activate your account',
      'active' || 'approved' => 'Application approved',
      'provisioning' || 'provisioning_failed' => 'Account setup in progress',
      _ => 'Application under review',
    };
    final description = switch (status) {
      'rejected' => 'Your driver application was rejected.',
      'awaiting_activation' =>
        'Your application was approved. Check ${app.pendingDriverApplicationEmail ?? 'your email'} for a secure activation link and set your password. Your driver profile remains offline until activation.',
      'active' || 'approved' =>
        'Your driver application has been approved!',
      'provisioning' ||
      'provisioning_failed' =>
        'Your application has been approved and the secure account setup is being completed. Please check again shortly.',
      _ => hasReceipt
          ? 'Your driver application was submitted successfully and is waiting for an administrator to review it.'
          : 'Your driver application is pending administrator review. Please wait for a decision.',
    };
    final Color statusColor = isRejected
        ? AppColors.danger
        : isApproved
            ? NeumorphicColors.brandEmerald
            : NeumorphicColors.brandAmber;
    final IconData statusIcon = isRejected
        ? Icons.cancel_outlined
        : isApproved
            ? Icons.check_circle_outline_rounded
            : Icons.hourglass_top_rounded;

    return Scaffold(
      backgroundColor: AppColors.canvasColor(dark),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: NeumorphicCard(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                radius: 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.25),
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        statusIcon,
                        size: 48,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textColor(dark),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: AppColors.subtextColor(dark),
                      ),
                    ),
                    if (isRejected &&
                        app.pendingDriverApplicationRejectionReason?.isNotEmpty ==
                            true) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: NeumorphicDecorations.inset(
                          isDark: dark,
                          radius: 12,
                          borderColor: AppColors.danger.withValues(alpha: 0.3),
                        ),
                        child: Text(
                          'Reason: ${app.pendingDriverApplicationRejectionReason}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    if (app.pendingDriverApplicationStatusError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Status could not be refreshed. Check your connection and try again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.danger.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    if (isApproved) ...[
                      NeumorphicButton(
                        text: _isNavigatingToDashboard
                            ? 'Loading Dashboard...'
                            : 'Go to Driver Dashboard',
                        icon: Icons.drive_eta_rounded,
                        isLoading: _isNavigatingToDashboard,
                        accentColor: NeumorphicColors.brandEmerald,
                        height: 52,
                        onPressed: _isNavigatingToDashboard
                            ? null
                            : () async {
                                setState(() => _isNavigatingToDashboard = true);
                                try {
                                  final initialized =
                                      await app.initializeApprovedDriverSession();
                                  if (!mounted) return;
                                  if (initialized &&
                                      app.currentUser?.isDriver == true) {
                                    widget.onNavigate(AppScreen.driverHome);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Your session could not be verified. Please sign in to access your dashboard.',
                                        ),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                    widget.onNavigate(AppScreen.login);
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(
                                        () => _isNavigatingToDashboard = false);
                                  }
                                }
                              },
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (hasReceipt && !isApproved && !isRejected) ...[
                      NeumorphicButton(
                        text: 'Check status',
                        icon: Icons.refresh_rounded,
                        isSecondary: true,
                        isLoading: _isRefreshing,
                        height: 48,
                        onPressed: _isRefreshing ? null : _refreshStatus,
                      ),
                      const SizedBox(height: 12),
                    ],
                    NeumorphicButton(
                      text: 'Go to login',
                      icon: Icons.login_rounded,
                      isSecondary: true,
                      height: 48,
                      onPressed: () async {
                        if (app.currentUser?.isDriver == true) await app.logout();
                        widget.onNavigate(AppScreen.login);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

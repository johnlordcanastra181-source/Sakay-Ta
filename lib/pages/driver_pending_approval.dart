import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../main.dart';
import '../state/app_state.dart';

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
    return Scaffold(
      backgroundColor: AppColors.canvasColor(dark),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isRejected
                      ? Icons.cancel_outlined
                      : isApproved
                          ? Icons.check_circle_outline_rounded
                          : Icons.hourglass_top_rounded,
                  size: 72,
                  color: isRejected ? Colors.redAccent : AppColors.primary,
                ),
                const SizedBox(height: 24),
                Text(title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textColor(dark))),
                const SizedBox(height: 12),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textColor(dark).withValues(alpha: 0.7)),
                ),
                if (isRejected &&
                    app.pendingDriverApplicationRejectionReason?.isNotEmpty ==
                        true) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Reason: ${app.pendingDriverApplicationRejectionReason}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textColor(dark),
                      fontWeight: FontWeight.w600,
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
                      color: AppColors.textColor(dark).withValues(alpha: 0.7),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                if (isApproved) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
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
                    icon: _isNavigatingToDashboard
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.drive_eta_rounded),
                    label: _isNavigatingToDashboard
                        ? const Text('Loading Dashboard...')
                        : const Text('Go to Driver Dashboard'),
                  ),
                  const SizedBox(height: 12),
                ],
                if (hasReceipt && !isApproved && !isRejected)
                  OutlinedButton.icon(
                    onPressed: _isRefreshing ? null : _refreshStatus,
                    icon: _isRefreshing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: const Text('Check status'),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    if (app.currentUser?.isDriver == true) await app.logout();
                    widget.onNavigate(AppScreen.login);
                  },
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Go to login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

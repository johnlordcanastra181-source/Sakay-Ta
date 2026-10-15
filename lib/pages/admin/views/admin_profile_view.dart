import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../services/supabase_service.dart';
import '../../../state/app_state.dart';
import '../../../core/constants.dart';
import '../admin_theme.dart';
import '../widgets/admin_widgets.dart';

/// Module 11: Manage Account & Security — Admin profile, password updates, security, and sign out.
class AdminProfileView extends StatefulWidget {
  const AdminProfileView({super.key, required this.onLogout});
  final VoidCallback onLogout;

  @override
  State<AdminProfileView> createState() => _AdminProfileViewState();
}

class _AdminProfileViewState extends State<AdminProfileView> {
  final _nameCtrl = TextEditingController();
  bool _isSavingName = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AppState>().currentUser;
    if (user != null) {
      _nameCtrl.text = user.fullName;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _showChangePasswordDialog() {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    String? error;
    bool isLoading = false;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return PopScope(
            canPop: !isLoading,
            child: AlertDialog(
              backgroundColor: AdminTheme.bgCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AdminTheme.border),
              ),
              title: const Row(
                children: [
                  Icon(Icons.lock_reset_rounded, color: AdminTheme.gold),
                  SizedBox(width: 10),
                  Text(
                    'Change Admin Password',
                    style: TextStyle(
                      color: AdminTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AdminTheme.navyLight.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AdminTheme.borderLight),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.privacy_tip_outlined,
                                color: AdminTheme.gold, size: 18),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'If your account was provisioned by a Super Administrator, changing your password ensures your login credentials remain private only to you.',
                                style: TextStyle(
                                  color: AdminTheme.textSecondary,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: AdminTheme.danger.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color:
                                    AdminTheme.danger.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: AdminTheme.dangerText, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  error!,
                                  style: const TextStyle(
                                    color: AdminTheme.dangerText,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      TextField(
                        controller: currentPassCtrl,
                        obscureText: obscureCurrent,
                        enabled: !isLoading,
                        style: const TextStyle(
                            color: AdminTheme.textPrimary, fontSize: 13),
                        decoration: AdminTheme.inputDecoration(
                          labelText: 'Current Password',
                          hintText: 'Enter password used to log in',
                        ).copyWith(
                          prefixIcon: const Icon(Icons.lock_outline_rounded,
                              color: AdminTheme.slate, size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureCurrent
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AdminTheme.textMuted,
                              size: 18,
                            ),
                            onPressed: () => setModalState(
                                () => obscureCurrent = !obscureCurrent),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: newPassCtrl,
                        obscureText: obscureNew,
                        enabled: !isLoading,
                        style: const TextStyle(
                            color: AdminTheme.textPrimary, fontSize: 13),
                        decoration: AdminTheme.inputDecoration(
                          labelText: 'New Password',
                          hintText: 'At least 6 characters',
                        ).copyWith(
                          prefixIcon: const Icon(Icons.vpn_key_outlined,
                              color: AdminTheme.slate, size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureNew
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AdminTheme.textMuted,
                              size: 18,
                            ),
                            onPressed: () =>
                                setModalState(() => obscureNew = !obscureNew),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: confirmPassCtrl,
                        obscureText: obscureConfirm,
                        enabled: !isLoading,
                        style: const TextStyle(
                            color: AdminTheme.textPrimary, fontSize: 13),
                        decoration: AdminTheme.inputDecoration(
                          labelText: 'Confirm New Password',
                          hintText: 'Re-enter your new password',
                        ).copyWith(
                          prefixIcon: const Icon(
                              Icons.check_circle_outline_rounded,
                              color: AdminTheme.slate,
                              size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AdminTheme.textMuted,
                              size: 18,
                            ),
                            onPressed: () => setModalState(
                                () => obscureConfirm = !obscureConfirm),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel',
                      style: TextStyle(color: AdminTheme.slate)),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final currentPass = currentPassCtrl.text;
                          final newPass = newPassCtrl.text;
                          final confirmPass = confirmPassCtrl.text;

                          if (currentPass.isEmpty) {
                            setModalState(() =>
                                error = 'Please enter your current password.');
                            return;
                          }
                          if (newPass.length < 6) {
                            setModalState(() => error =
                                'New password must be at least 6 characters.');
                            return;
                          }
                          if (newPass == currentPass) {
                            setModalState(() => error =
                                'New password must be different from your current password.');
                            return;
                          }
                          if (newPass != confirmPass) {
                            setModalState(
                                () => error = 'New passwords do not match.');
                            return;
                          }

                          setModalState(() {
                            isLoading = true;
                            error = null;
                          });

                          try {
                            final messenger =
                                ScaffoldMessenger.of(this.context);
                            await context.read<AppState>().changeAdminPassword(
                                  newPass,
                                  currentPassword: currentPass,
                                );
                            if (ctx.mounted) {
                              Navigator.of(ctx).pop();
                              messenger.showSnackBar(
                                const SnackBar(
                                  backgroundColor: AdminTheme.green,
                                  content: Text(
                                      'Password updated successfully! Please remember your new password.'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (!ctx.mounted) return;
                            setModalState(() {
                              isLoading = false;
                              final msg = e.toString();
                              error = msg.startsWith('FormatException: ')
                                  ? msg.replaceFirst('FormatException: ', '')
                                  : (msg.startsWith('Exception: ')
                                      ? msg.replaceFirst('Exception: ', '')
                                      : 'Unable to update password: $e');
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.terracotta,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Save New Password',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;
    final name = user?.fullName ?? 'Administrator';
    final email = user?.email ?? '';
    final mobile = user?.mobile ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminSectionHeader(
          title: 'Administrator Account',
          subtitle:
              'Manage profile information, authentication security, and session management.',
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 800;

            return Flex(
              direction: isWide ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Card
                Expanded(
                  flex: isWide ? 3 : 0,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: AdminTheme.cardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  AdminTheme.terracotta.withValues(alpha: 0.2),
                              radius: 32,
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'A',
                                style: const TextStyle(
                                  color: AdminTheme.terracotta,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                        color: AdminTheme.textPrimary,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    email,
                                    style: const TextStyle(
                                        color: AdminTheme.textSecondary,
                                        fontSize: 13),
                                  ),
                                  Text(
                                    mobile,
                                    style: const TextStyle(
                                        color: AdminTheme.textMuted,
                                        fontSize: 12),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: (user?.isSuperAdmin == true
                                              ? AdminTheme.gold
                                              : AdminTheme.terracotta)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: (user?.isSuperAdmin == true
                                                  ? AdminTheme.gold
                                                  : AdminTheme.terracotta)
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      user?.isSuperAdmin == true
                                          ? '⭐ Super Administrator'
                                          : '🛡️ Administrator',
                                      style: TextStyle(
                                          color: user?.isSuperAdmin == true
                                              ? AdminTheme.gold
                                              : AdminTheme.terracotta,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Divider(color: AdminTheme.borderLight),
                        const SizedBox(height: 16),
                        const Text('EDIT PROFILE DETAILS',
                            style: TextStyle(
                                color: AdminTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _nameCtrl,
                          style: const TextStyle(
                              color: AdminTheme.textPrimary, fontSize: 13),
                          decoration: AdminTheme.inputDecoration(
                            labelText: 'Administrator Display Name',
                            hintText: 'Enter full name',
                            prefixIcon: const Icon(Icons.person_outline_rounded,
                                color: AdminTheme.slate, size: 18),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _isSavingName
                              ? null
                              : () async {
                                  if (_nameCtrl.text.trim().isEmpty) return;
                                  setState(() => _isSavingName = true);
                                  await context.read<AppState>().updateProfile(
                                      fullName: _nameCtrl.text.trim());
                                  if (mounted) {
                                    setState(() => _isSavingName = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          backgroundColor: AdminTheme.green,
                                          content: Text('Profile updated.')),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.save_rounded, size: 16),
                          label: _isSavingName
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('Save Changes'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminTheme.terracotta,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Divider(color: AdminTheme.borderLight),
                        const SizedBox(height: 16),
                        const Text('SECURITY & CREDENTIALS',
                            style: TextStyle(
                                color: AdminTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8)),
                        const SizedBox(height: 6),
                        const Text(
                          'If your account was provisioned with an initial password by a Super Administrator, changing it now guarantees that your credentials remain completely private to you.',
                          style: TextStyle(
                              color: AdminTheme.textSecondary,
                              fontSize: 12,
                              height: 1.4),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: _showChangePasswordDialog,
                          icon: const Icon(Icons.lock_reset_rounded, size: 16),
                          label: const Text('Change My Password'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminTheme.navy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (isWide)
                  const SizedBox(width: 16)
                else
                  const SizedBox(height: 16),

                // Environment Card
                Expanded(
                  flex: isWide ? 2 : 0,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: AdminTheme.cardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('SYSTEM & ENVIRONMENT',
                            style: TextStyle(
                                color: AdminTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        _buildEnvRow('Supabase Project', 'Sakay Ta'),
                        _buildEnvRow(
                            'Supabase Database',
                            SupabaseService.isConfigured
                                ? 'Connected (Live)'
                                : 'Local Database'),
                        _buildEnvRow(
                            'Supabase Storage', 'Connected (Storage Bucket)'),
                        _buildEnvRow('App Version', '1.1.0 (Admin Web)'),
                        _buildEnvRow(
                            'Session Started',
                            DateFormat('MMMM d, yyyy h:mm a')
                                .format(DateTime.now())),
                        const SizedBox(height: 24),
                        const Divider(color: AdminTheme.borderLight),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final confirm = await showAdminConfirmDialog(
                                context: context,
                                title: 'Sign Out',
                                message:
                                    'Are you sure you want to sign out of the Sakay Ta Admin Dashboard?',
                                confirmText: 'Sign Out',
                                confirmColor: AdminTheme.danger,
                              );
                              if (confirm == true) {
                                widget.onLogout();
                              }
                            },
                            icon: const Icon(Icons.logout_rounded, size: 16),
                            label: const Text('Sign Out of Admin Portal'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  AdminTheme.danger.withValues(alpha: 0.15),
                              foregroundColor: AdminTheme.dangerText,
                              elevation: 0,
                              side: BorderSide(
                                  color:
                                      AdminTheme.danger.withValues(alpha: 0.3)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: AdminTheme.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('FARE MATRIX (READ-ONLY)',
                  style: TextStyle(
                      color: AdminTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Go to Fare Matrix page to edit these rates.',
                  style: TextStyle(color: AdminTheme.textMuted, fontSize: 12)),
              const SizedBox(height: 16),
              const Divider(color: AdminTheme.borderLight),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _buildReadOnlyFare(context, VehicleType.tricycle)),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _buildReadOnlyFare(context, VehicleType.habal)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEnvRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(color: AdminTheme.textMuted, fontSize: 12)),
          Text(value,
              style: const TextStyle(
                  color: AdminTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildReadOnlyFare(BuildContext context, VehicleType type) {
    final matrix = context.watch<AppState>().getFareMatrixFor(type);
    final name = type == VehicleType.tricycle ? 'Tricycle' : 'Habal-Habal';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTheme.bgCard,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name,
              style: const TextStyle(
                  color: AdminTheme.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Base Fare: ₱${matrix.baseFare}',
              style: const TextStyle(color: AdminTheme.slate)),
          Text('Included Distance: ${matrix.includedBaseDistance} km',
              style: const TextStyle(color: AdminTheme.slate)),
          Text('Per Km: ₱${matrix.perKmRate}',
              style: const TextStyle(color: AdminTheme.slate)),
          Text('Minimum Fare: ₱${matrix.minimumFare}',
              style: const TextStyle(color: AdminTheme.slate)),
          const Text('Rounding: nearest ₱5',
              style: TextStyle(color: AdminTheme.slate)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../models/admin_account.dart';
import '../../../state/app_state.dart';
import '../../../services/supabase_service.dart';
import '../admin_theme.dart';
import '../widgets/admin_widgets.dart';

/// Module 10: Admin Account Management
/// Super-admin management of administrator accounts directly backed by
/// Supabase Auth and the server-side admin role records.
class AdminAccountsView extends StatefulWidget {
  const AdminAccountsView({super.key});

  @override
  State<AdminAccountsView> createState() => _AdminAccountsViewState();
}

class _AdminAccountsViewState extends State<AdminAccountsView> {
  // ── Create Administrator Modal ─────────────────────────────────────────────

  void _showCreateAdminDialog() {
    final app = context.read<AppState>();
    if (app.currentUser?.isSuperAdmin != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AdminTheme.danger,
          content: Text(
              'Access Denied: Only Super Administrators can create administrator accounts.'),
        ),
      );
      return;
    }

    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final deptCtrl = TextEditingController(text: 'Operations');
    String selectedRole = 'admin'; // 'super_admin' | 'admin'
    String selectedStatus = 'active'; // 'active' | 'disabled'
    bool obscurePassword = true;
    bool isLoading = false;
    String? errorMsg;

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
                    Icon(Icons.person_add_alt_1_rounded,
                        color: AdminTheme.gold),
                    SizedBox(width: 10),
                    Text(
                      'Create Admin Account',
                      style: TextStyle(
                        color: AdminTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 520,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Assign your team member a login email, password, role, and account status.',
                          style: TextStyle(
                            color: AdminTheme.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (errorMsg != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: AdminTheme.danger.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AdminTheme.danger.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: AdminTheme.dangerText,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    errorMsg!,
                                    style: const TextStyle(
                                      color: AdminTheme.dangerText,
                                      fontSize: 12,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Full Name
                        TextField(
                          controller: nameCtrl,
                          enabled: !isLoading,
                          style: const TextStyle(
                            color: AdminTheme.textPrimary,
                            fontSize: 13,
                          ),
                          decoration: AdminTheme.inputDecoration(
                            labelText: 'Full Name',
                            hintText: 'e.g. Maria Clara Santos',
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Email address for Supabase Auth login.
                        TextField(
                          controller: emailCtrl,
                          enabled: !isLoading,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(
                            color: AdminTheme.textPrimary,
                            fontSize: 13,
                          ),
                          decoration: AdminTheme.inputDecoration(
                            labelText: 'Email Address (Login Username)',
                            hintText: 'admin@sakayta.app',
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Password
                        TextField(
                          controller: passCtrl,
                          enabled: !isLoading,
                          obscureText: obscurePassword,
                          style: const TextStyle(
                            color: AdminTheme.textPrimary,
                            fontSize: 13,
                          ),
                          decoration: AdminTheme.inputDecoration(
                            labelText: 'Password',
                            hintText: 'At least 6 characters',
                          ).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AdminTheme.textMuted,
                                size: 18,
                              ),
                              onPressed: () {
                                setModalState(() {
                                  obscurePassword = !obscurePassword;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Role Selector
                        DropdownButtonFormField<String>(
                          initialValue: selectedRole,
                          dropdownColor: AdminTheme.bgCard,
                          style: const TextStyle(
                            color: AdminTheme.textPrimary,
                            fontSize: 13,
                          ),
                          decoration: AdminTheme.inputDecoration(
                            labelText: 'Administrator Role',
                            hintText: 'Select role',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'admin',
                              child: Row(
                                children: [
                                  Text('🛡️ Admin / Staff  ',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  Text('(Verify Drivers, Rides & Reports)',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AdminTheme.textMuted)),
                                ],
                              ),
                            ),
                          ],
                          onChanged: isLoading
                              ? null
                              : (val) => setModalState(
                                  () => selectedRole = val ?? 'admin'),
                        ),
                        const SizedBox(height: 12),

                        // Account Status (Active vs Disabled)
                        DropdownButtonFormField<String>(
                          initialValue: selectedStatus,
                          dropdownColor: AdminTheme.bgCard,
                          style: const TextStyle(
                            color: AdminTheme.textPrimary,
                            fontSize: 13,
                          ),
                          decoration: AdminTheme.inputDecoration(
                            labelText: 'Initial Account Status',
                            hintText: 'Select account status',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'active',
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle_outline,
                                      color: AdminTheme.successText, size: 16),
                                  SizedBox(width: 8),
                                  Text('Active ',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AdminTheme.successText)),
                                  Text('(Can sign in immediately)',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AdminTheme.textMuted)),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'disabled',
                              child: Row(
                                children: [
                                  Icon(Icons.block_outlined,
                                      color: AdminTheme.dangerText, size: 16),
                                  SizedBox(width: 8),
                                  Text('Disabled ',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AdminTheme.dangerText)),
                                  Text(
                                      '(Created but blocked from login until activated)',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AdminTheme.textMuted)),
                                ],
                              ),
                            ),
                          ],
                          onChanged: isLoading
                              ? null
                              : (val) => setModalState(
                                  () => selectedStatus = val ?? 'active'),
                        ),
                        const SizedBox(height: 12),

                        // Department / Unit
                        TextField(
                          controller: deptCtrl,
                          enabled: !isLoading,
                          style: const TextStyle(
                            color: AdminTheme.textPrimary,
                            fontSize: 13,
                          ),
                          decoration: AdminTheme.inputDecoration(
                            labelText: 'Department / Unit',
                            hintText:
                                'e.g. Operations, Customer Care, Compliance',
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
                            final fullName = nameCtrl.text.trim();
                            final email = emailCtrl.text.trim().toLowerCase();
                            final password = passCtrl.text;
                            final department = deptCtrl.text.trim();

                            // Form Validation
                            if (fullName.isEmpty || fullName.length < 2) {
                              setModalState(() => errorMsg =
                                  'Please enter a valid administrator full name.');
                              return;
                            }
                            if (email.isEmpty ||
                                !RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$')
                                    .hasMatch(email)) {
                              setModalState(() => errorMsg =
                                  'Please enter a valid email address.');
                              return;
                            }
                            if (password.length < 6) {
                              setModalState(() => errorMsg =
                                  'Password must be at least 6 characters.');
                              return;
                            }

                            setModalState(() {
                              isLoading = true;
                              errorMsg = null;
                            });

                            try {
                              final app = context.read<AppState>();

                              // Provision the account through the secure admin flow.
                              await app.createAdminAccount(
                                fullName: fullName,
                                email: email,
                                password: password,
                                role: selectedRole,
                                status: selectedStatus,
                                permissions: selectedRole == 'super_admin'
                                    ? AdminPermissions.all
                                    : 'verify_drivers,manage_reports,monitor_rides',
                                department: department.isNotEmpty
                                    ? department
                                    : 'Operations',
                              );

                              if (ctx.mounted) {
                                Navigator.of(ctx).pop();
                                _showCredentialSummaryDialog(
                                  fullName: fullName,
                                  email: email,
                                  password: password,
                                  role: selectedRole,
                                  status: selectedStatus,
                                );
                              }
                            } catch (e) {
                              if (!ctx.mounted) return;
                              setModalState(() {
                                isLoading = false;
                                errorMsg = e
                                    .toString()
                                    .replaceFirst('Exception: ', '')
                                    .replaceFirst('StateError: ', '');
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.terracotta,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: isLoading
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white)),
                              SizedBox(width: 10),
                              Text('Creating Account...'),
                            ],
                          )
                        : const Text('Create Admin Account'),
                  ),
                ],
              ));
        },
      ),
    );
  }

  // ── Post-Creation Credential Handover Modal ────────────────────────────────
  void _showCredentialSummaryDialog({
    required String fullName,
    required String email,
    required String password,
    required String role,
    required String status,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AdminTheme.border),
        ),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AdminTheme.green, size: 24),
            SizedBox(width: 10),
            Text(
              'Admin Account Created',
              style: TextStyle(
                color: AdminTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AdminTheme.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AdminTheme.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: AdminTheme.successText, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        status == 'active'
                            ? 'The administrator can sign in with these credentials.'
                            : 'This account is disabled. Activate it before the administrator can sign in.',
                        style: TextStyle(
                            color: AdminTheme.successText,
                            fontSize: 12,
                            height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _credentialRow('Full Name', fullName),
              const SizedBox(height: 8),
              _credentialRow('Login Email', email),
              const SizedBox(height: 8),
              _credentialRow('Assigned Password', password),
              const SizedBox(height: 8),
              _credentialRow(
                  'Role',
                  role == 'super_admin'
                      ? '⭐ Super Admin'
                      : '🛡️ Admin / Staff'),
              const SizedBox(height: 8),
              _credentialRow('Initial Status',
                  status == 'active' ? '✅ ACTIVE' : '⛔ DISABLED'),
              const SizedBox(height: 16),
              const Text(
                'Keep these credentials private. Passwords are not stored in the cloud profile.',
                style: TextStyle(
                    color: AdminTheme.textMuted,
                    fontSize: 11,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              final text = 'Sakay Ta Administrator Credentials:\n'
                  'Name: $fullName\n'
                  'Email: $email\n'
                  'Password: $password\n'
                  'Role: ${role == 'super_admin' ? 'Super Admin' : 'Admin'}\n'
                  'Status: $status\n'
                  'Portal: Flutter Web Admin Portal';
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: AdminTheme.green,
                  content: Text('Credentials copied to clipboard!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy Credentials'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminTheme.gold,
              side: const BorderSide(color: AdminTheme.gold),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.terracotta,
              foregroundColor: Colors.white,
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _credentialRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AdminTheme.bgInput,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AdminTheme.borderLight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AdminTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          SelectableText(
            value,
            style: const TextStyle(
                color: AdminTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ── Edit Administrator Modal ───────────────────────────────────────────────

  void _showEditAdminDialog(AdminAccount admin) {
    final app = context.read<AppState>();
    if (app.currentUser?.isSuperAdmin != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AdminTheme.danger,
          content: Text(
              'Access Denied: Only Super Administrators can edit administrator accounts.'),
        ),
      );
      return;
    }

    final nameCtrl = TextEditingController(text: admin.fullName);
    final deptCtrl = TextEditingController(text: admin.department);
    String selectedRole = admin.isSuperAdmin ? 'super_admin' : 'admin';
    bool isLoading = false;
    String? errorMsg;

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
                title: Row(
                  children: [
                    const Icon(Icons.edit_note_rounded, color: AdminTheme.gold),
                    const SizedBox(width: 10),
                    Text(
                      'Edit Administrator: ${admin.fullName}',
                      style: const TextStyle(
                        color: AdminTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 500,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'UID: ${admin.id}  •  Email: ${admin.email}',
                          style: const TextStyle(
                              color: AdminTheme.textMuted, fontSize: 11),
                        ),
                        const SizedBox(height: 16),
                        if (errorMsg != null) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: AdminTheme.danger.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color:
                                      AdminTheme.danger.withValues(alpha: 0.4)),
                            ),
                            child: Text(errorMsg!,
                                style: const TextStyle(
                                    color: AdminTheme.dangerText,
                                    fontSize: 12)),
                          ),
                        ],
                        TextField(
                          controller: nameCtrl,
                          enabled: !isLoading,
                          style: const TextStyle(
                              color: AdminTheme.textPrimary, fontSize: 13),
                          decoration: AdminTheme.inputDecoration(
                              labelText: 'Full Name', hintText: 'Full Name'),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedRole,
                          dropdownColor: AdminTheme.bgCard,
                          style: const TextStyle(
                              color: AdminTheme.textPrimary, fontSize: 13),
                          decoration: AdminTheme.inputDecoration(
                              labelText: 'Administrator Role',
                              hintText: 'Select role'),
                          items: const [
                            DropdownMenuItem(
                                value: 'super_admin_hidden',
                                child: Text('⭐ Super Admin (Full Access)')),
                            DropdownMenuItem(
                                value: 'admin',
                                child: Text(
                                    '🛡️ Admin / Reviewer (Operational Access)')),
                          ],
                          onChanged: isLoading
                              ? null
                              : (val) => setModalState(
                                  () => selectedRole = val ?? 'admin'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: deptCtrl,
                          enabled: !isLoading,
                          style: const TextStyle(
                              color: AdminTheme.textPrimary, fontSize: 13),
                          decoration: AdminTheme.inputDecoration(
                              labelText: 'Department / Unit',
                              hintText: 'Department'),
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
                            final fullName = nameCtrl.text.trim();
                            if (fullName.isEmpty) {
                              setModalState(() =>
                                  errorMsg = 'Full name cannot be empty.');
                              return;
                            }

                            setModalState(() {
                              isLoading = true;
                              errorMsg = null;
                            });

                            try {
                              final updated = admin.copyWith(
                                fullName: fullName,
                                role: selectedRole,
                                permissions: selectedRole == 'super_admin'
                                    ? AdminPermissions.all
                                    : 'verify_drivers,manage_reports,monitor_rides',
                                department: deptCtrl.text.trim(),
                                updatedAt: DateTime.now(),
                              );

                              await context
                                  .read<AppState>()
                                  .updateAdminAccount(updated);

                              if (ctx.mounted) {
                                Navigator.of(ctx).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    backgroundColor: AdminTheme.green,
                                    content: Text(
                                        'Administrator profile updated successfully!'),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (!ctx.mounted) return;
                              setModalState(() {
                                isLoading = false;
                                errorMsg = e
                                    .toString()
                                    .replaceFirst('Exception: ', '')
                                    .replaceFirst('StateError: ', '');
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.terracotta,
                      foregroundColor: Colors.white,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Save Changes'),
                  ),
                ],
              ));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final currentUser = app.currentUser;
    // Only super admins can view or manage admin accounts.
    final canManageAdmins = currentUser?.isSuperAdmin == true;

    if (!canManageAdmins) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: AdminTheme.cardDecoration(),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AdminTheme.danger.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.gpp_bad_rounded,
                    color: AdminTheme.dangerText, size: 52),
              ),
              const SizedBox(height: 20),
              const Text(
                'Super Administrator Access Required',
                style: TextStyle(
                  color: AdminTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Only Super Administrators have permission to view and manage administrator accounts.\nContact your Super Administrator if you require access.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AdminTheme.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminSectionHeader(
          title: 'Admin Account Management',
          subtitle: SupabaseService.isConfigured
              ? 'Create and manage administrator access for your team.'
              : 'Local accounts are saved in this browser. Use this same browser to sign in.',
          actions: [
            ElevatedButton.icon(
              onPressed: _showCreateAdminDialog,
              icon: const Icon(Icons.person_add_rounded, size: 16),
              label: const Text('Create Admin Account'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.terracotta,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),

        // ── Developer Provisioning Workflow Info Banner ───────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: AdminTheme.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AdminTheme.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AdminTheme.terracotta.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.key_rounded,
                    color: AdminTheme.terracotta, size: 20),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Super Admin Only',
                      style: TextStyle(
                        color: AdminTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Only Super Administrators can create, edit, activate/deactivate, or delete administrator accounts.',
                      style: TextStyle(
                        color: AdminTheme.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Admin Accounts Table ─────────────────────────────────────────────
        Container(
          decoration: AdminTheme.cardDecoration(),
          child: AdminDataStreamBuilder<List<AdminAccount>>(
            section: 'admin_accounts',
            stream: app.adminAccountsStream(),
            builder: (context, snapshot) {
              final allAdmins = snapshot.data ?? <AdminAccount>[];
              // Hide the root super-admin account from non-super-admin viewers
              // for security — only a super admin can see the system account.
              final isSuperAdmin = currentUser?.isSuperAdmin == true;
              final admins = isSuperAdmin
                  ? allAdmins
                  : allAdmins
                      .where((a) => a.id != AppState.defaultSuperAdmin.id)
                      .toList();
              if (snapshot.connectionState == ConnectionState.waiting &&
                  admins.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AdminTheme.terracotta)),
                );
              }

              if (snapshot.hasError && admins.isEmpty) {
                return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(children: [
                      const Text('Unable to load administrator accounts.'),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                          onPressed: () => setState(() {}),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry')),
                    ]));
              }
              if (admins.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(48),
                  child: AdminEmptyState(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'No Administrators Listed',
                    subtitle:
                        'Create an administrator account to grant team members access to the dashboard.',
                  ),
                );
              }

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor:
                      WidgetStateProperty.all(AdminTheme.bgSecondary),
                  horizontalMargin: 16,
                  columnSpacing: 24,
                  columns: const [
                    DataColumn(
                        label: Text('ADMINISTRATOR',
                            style: TextStyle(
                                color: AdminTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('LOGIN EMAIL',
                            style: TextStyle(
                                color: AdminTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('ROLE',
                            style: TextStyle(
                                color: AdminTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('DEPARTMENT',
                            style: TextStyle(
                                color: AdminTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('STATUS',
                            style: TextStyle(
                                color: AdminTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('LAST LOGIN',
                            style: TextStyle(
                                color: AdminTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('ACTIONS',
                            style: TextStyle(
                                color: AdminTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                  ],
                  rows: admins.map((admin) {
                    final isSuper = admin.isSuperAdmin;
                    final isSelf = currentUser?.id == admin.id;

                    return DataRow(
                      cells: [
                        // Administrator Name & UID
                        DataCell(
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: isSuper
                                    ? AdminTheme.gold.withValues(alpha: 0.2)
                                    : AdminTheme.navyLight,
                                radius: 15,
                                child: Text(
                                  admin.fullName.isNotEmpty
                                      ? admin.fullName[0].toUpperCase()
                                      : 'A',
                                  style: TextStyle(
                                    color: isSuper
                                        ? AdminTheme.gold
                                        : AdminTheme.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        admin.fullName,
                                        style: const TextStyle(
                                            color: AdminTheme.textPrimary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      if (isSelf) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: AdminTheme.terracotta
                                                .withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: const Text('You',
                                              style: TextStyle(
                                                  color: AdminTheme.terracotta,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    'UID: ${admin.id.length > 14 ? '${admin.id.substring(0, 14)}...' : admin.id}',
                                    style: const TextStyle(
                                        color: AdminTheme.textMuted,
                                        fontSize: 10),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Email
                        DataCell(Text(admin.email,
                            style: const TextStyle(
                                color: AdminTheme.textSecondary,
                                fontSize: 12))),

                        // Role Badge
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isSuper
                                  ? AdminTheme.gold.withValues(alpha: 0.12)
                                  : AdminTheme.bgInput,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: isSuper
                                      ? AdminTheme.gold.withValues(alpha: 0.3)
                                      : AdminTheme.borderLight),
                            ),
                            child: Text(
                              isSuper ? '⭐ Super Admin' : '🛡️ Admin',
                              style: TextStyle(
                                color: isSuper
                                    ? AdminTheme.gold
                                    : AdminTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        // Department
                        DataCell(Text(admin.department,
                            style: const TextStyle(
                                color: AdminTheme.textMuted, fontSize: 12))),

                        // Status Badge
                        DataCell(AdminStatusBadge(status: admin.status)),

                        // Last Login
                        DataCell(
                          Text(
                            admin.lastLogin != null
                                ? DateFormat('MMM d, h:mm a')
                                    .format(admin.lastLogin!)
                                : 'Never',
                            style: const TextStyle(
                                color: AdminTheme.textMuted, fontSize: 12),
                          ),
                        ),

                        // Action Buttons
                        DataCell(
                          Row(
                            children: [
                              // Edit Button
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                color: canManageAdmins
                                    ? AdminTheme.gold
                                    : AdminTheme.textMuted
                                        .withValues(alpha: 0.3),
                                tooltip: canManageAdmins
                                    ? 'Edit Administrator'
                                    : 'Requires Super Administrator permission',
                                onPressed: canManageAdmins
                                    ? () => _showEditAdminDialog(admin)
                                    : null,
                              ),

                              // Toggle Active / Deactivate (cannot self-deactivate)
                              IconButton(
                                icon: Icon(
                                  admin.isActive
                                      ? Icons.toggle_on_rounded
                                      : Icons.toggle_off_rounded,
                                  color: !canManageAdmins || isSelf
                                      ? AdminTheme.textMuted
                                          .withValues(alpha: 0.3)
                                      : (admin.isActive
                                          ? AdminTheme.successText
                                          : AdminTheme.dangerText),
                                  size: 24,
                                ),
                                tooltip: !canManageAdmins
                                    ? 'Requires Super Administrator permission'
                                    : (isSelf
                                        ? 'Cannot deactivate your own account'
                                        : (admin.isActive
                                            ? 'Deactivate Administrator'
                                            : 'Activate Administrator')),
                                onPressed: !canManageAdmins || isSelf
                                    ? null
                                    : () async {
                                        final willDeactivate = admin.isActive;
                                        final confirmed =
                                            await showAdminConfirmDialog(
                                          context: context,
                                          title: willDeactivate
                                              ? 'Deactivate Administrator'
                                              : 'Activate Administrator',
                                          message: willDeactivate
                                              ? 'Are you sure you want to deactivate "${admin.fullName}"? They will be immediately blocked from signing into the Admin Portal.'
                                              : 'Are you sure you want to reactivate "${admin.fullName}"? They will regain access to the Admin Portal.',
                                          confirmText: willDeactivate
                                              ? 'Deactivate'
                                              : 'Activate',
                                        );

                                        if (confirmed == true &&
                                            context.mounted) {
                                          try {
                                            await context
                                                .read<AppState>()
                                                .toggleAdminAccountStatus(
                                                    admin.id, admin.status);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  backgroundColor:
                                                      willDeactivate
                                                          ? AdminTheme.danger
                                                          : AdminTheme.green,
                                                  content: Text(
                                                      'Administrator "${admin.fullName}" ${willDeactivate ? 'deactivated' : 'activated'}.'),
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                    backgroundColor:
                                                        AdminTheme.danger,
                                                    content: Text(
                                                        'An error occurred. Please try again.')),
                                              );
                                            }
                                          }
                                        }
                                      },
                              ),

                              // Delete Admin (cannot self-delete)
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 18),
                                color: !canManageAdmins || isSelf
                                    ? AdminTheme.textMuted
                                        .withValues(alpha: 0.3)
                                    : AdminTheme.dangerText,
                                tooltip: !canManageAdmins
                                    ? 'Requires Super Administrator permission'
                                    : (isSelf
                                        ? 'Cannot delete your own account'
                                        : 'Permanently Delete Admin'),
                                onPressed: !canManageAdmins || isSelf
                                    ? null
                                    : () async {
                                        final confirmed =
                                            await showAdminConfirmDialog(
                                          context: context,
                                          title: 'Delete Administrator',
                                          message:
                                              'Are you sure you want to permanently delete administrator "${admin.fullName}" (${admin.email})? This action cannot be undone.',
                                          confirmText: 'Delete Permanently',
                                        );

                                        if (confirmed == true &&
                                            context.mounted) {
                                          try {
                                            await context
                                                .read<AppState>()
                                                .deleteAdminAccount(admin.id);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  backgroundColor:
                                                      AdminTheme.green,
                                                  content: Text(
                                                      'Administrator "${admin.fullName}" deleted successfully.'),
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                    backgroundColor:
                                                        AdminTheme.danger,
                                                    content: Text(
                                                        'An error occurred. Please try again.')),
                                              );
                                            }
                                          }
                                        }
                                      },
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

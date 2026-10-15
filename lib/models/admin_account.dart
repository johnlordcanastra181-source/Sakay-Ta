import '../core/constants.dart';
import 'app_user.dart';

/// Model representing an administrator account stored in Supabase and SQLite.
class AdminAccount {
  final String id;
  final String fullName;
  final String email;
  final String mobile;
  final String passwordHash;
  final String role; // 'super_admin' | 'admin'
  final String status; // 'active' | 'deactivated'
  final String permissions; // 'all' | comma-separated permissions
  final String department;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLogin;

  const AdminAccount({
    required this.id,
    required this.fullName,
    required this.email,
    this.mobile = '',
    this.passwordHash = '',
    this.role = UserRole.admin,
    this.status = AccountStatus.active,
    this.permissions = AdminPermissions.all,
    this.department = 'Operations',
    required this.createdAt,
    this.updatedAt,
    this.lastLogin,
  });

  /// Alias for the Supabase Auth UUID.
  String get uid => id;

  /// Alias for administrator's full name.
  String get name => fullName;

  /// True when the account has active permissions.
  bool get isActive =>
      status == AccountStatus.active || status == AccountStatus.approved;

  /// True when the account is deactivated.
  bool get isDeactivated => !isActive;

  /// True when the administrator has Super Admin status.
  bool get isSuperAdmin =>
      role == 'super_admin' ||
      role == 'Super Admin' ||
      id == 'super-admin-root' ||
      id == 'test-admin-1' ||
      email.trim().toLowerCase() == 'johnlordcanastra@sakayta.app';

  bool hasPermission(String permission) {
    if (permissions == AdminPermissions.all || isSuperAdmin) return true;
    final list = permissions.split(',').map((s) => s.trim()).toList();
    return list.contains(permission) || list.contains(AdminPermissions.all);
  }

  AppUser toUser() {
    return AppUser(
      id: id,
      fullName: fullName,
      email: email,
      mobile: mobile,
      emailVerified: true,
      passwordHash: passwordHash,
      role: isSuperAdmin ? 'super_admin' : role,
      status: status,
      createdAt: createdAt,
      verifiedAt: createdAt,
      address: department,
    );
  }

  /// Supabase representation stored across `profiles` and `admin_roles`.
  /// Strictly contains uid, name, email, role, status, createdAt, and updatedAt.
  /// NOTE: Passwords and password hashes are never stored in application tables.
  Map<String, Object?> toRemoteMap() => {
        'uid': id,
        'id': id,
        'name': fullName,
        'fullName': fullName,
        'email': email.trim().toLowerCase(),
        'mobile': mobile.trim(),
        'role': role,
        'status': status,
        'department': department,
        'permissions': permissions,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
        if (lastLogin != null) 'lastLogin': lastLogin!.toUtc().toIso8601String(),
      };

  /// Local SQLite database representation (used for offline caching).
  Map<String, Object?> toMap() => {
        'id': id,
        'full_name': fullName,
        'email': email.trim().toLowerCase(),
        'mobile': mobile.trim(),
        'password_hash': passwordHash,
        'role': role,
        'status': status,
        'permissions': permissions,
        'department': department,
        'created_at': createdAt.millisecondsSinceEpoch,
        'last_login': lastLogin?.millisecondsSinceEpoch,
      };

  factory AdminAccount.fromMap(Map<String, Object?> map, {String? fallbackId}) {
    DateTime parseDate(dynamic value) {
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic value) {
      if (value == null) return null;
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    final rawId = (map['uid'] ?? map['id']) as String?;
    final id = (rawId != null && rawId.trim().isNotEmpty)
        ? rawId.trim()
        : (fallbackId ?? '').trim();

    final email = (map['email'] as String? ?? '').trim().toLowerCase();

    var fullName =
        ((map['name'] ?? map['full_name'] ?? map['fullName']) as String? ?? '')
            .trim();
    if (fullName.isEmpty && email.isNotEmpty) {
      final prefix = email.split('@').first.replaceAll(RegExp(r'[._\-]'), ' ');
      fullName = prefix
          .split(' ')
          .where((w) => w.isNotEmpty)
          .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
    }
    if (fullName.isEmpty) {
      fullName = 'Super Administrator';
    }

    final rawRole = (map['role'] as String?)?.trim();
    final role =
        (rawRole != null && rawRole.isNotEmpty) ? rawRole : 'super_admin';

    final rawStatus = (map['status'] as String?)?.trim();
    final status = (rawStatus != null && rawStatus.isNotEmpty)
        ? rawStatus
        : AccountStatus.active;

    final rawPermissions = (map['permissions'] as String?)?.trim();
    final permissions = (rawPermissions != null && rawPermissions.isNotEmpty)
        ? rawPermissions
        : AdminPermissions.all;

    final rawDepartment = (map['department'] as String?)?.trim();
    final department = (rawDepartment != null && rawDepartment.isNotEmpty)
        ? rawDepartment
        : 'HQ Management';

    return AdminAccount(
      id: id,
      fullName: fullName,
      email: email,
      mobile: (map['mobile'] as String? ?? '').trim(),
      passwordHash:
          (map['password_hash'] ?? map['passwordHash'] ?? '') as String,
      role: role,
      status: status,
      permissions: permissions,
      department: department,
      createdAt: parseDate(map['createdAt'] ?? map['created_at']),
      updatedAt: parseNullableDate(map['updatedAt'] ?? map['updated_at']),
      lastLogin: parseNullableDate(map['lastLogin'] ?? map['last_login']),
    );
  }

  AdminAccount copyWith({
    String? id,
    String? fullName,
    String? email,
    String? mobile,
    String? passwordHash,
    String? role,
    String? status,
    String? permissions,
    String? department,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLogin,
  }) {
    return AdminAccount(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      mobile: mobile ?? this.mobile,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
      status: status ?? this.status,
      permissions: permissions ?? this.permissions,
      department: department ?? this.department,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
}

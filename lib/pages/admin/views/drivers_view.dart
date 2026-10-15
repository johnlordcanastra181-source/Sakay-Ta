import 'dart:async';
import '../../../services/supabase/admin_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/app_user.dart';
import '../../../models/driver_profile.dart';
import '../../../services/supabase_service.dart';
import '../../../state/app_state.dart';
import '../admin_theme.dart';
import '../widgets/admin_widgets.dart';

/// Module 6: Manage Driver Accounts & Suspend Driver — Profiles, ratings, vehicle info, suspension & reactivation.
class AdminDriversView extends StatefulWidget {
  const AdminDriversView({super.key});

  @override
  State<AdminDriversView> createState() => _AdminDriversViewState();
}

class _AdminDriversViewState extends State<AdminDriversView> {
  final _searchCtrl = TextEditingController();
  String _selectedStatus = 'all';

  List<AppUser> _drivers = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  Timer? _debounce;
  String? _deletingDriverId;

  int _offset = 0;
  final int _limit = 50;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetchDrivers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _refreshList();
    });
  }

  void _onStatusChanged(String? val) {
    if (val == null || val == _selectedStatus) return;
    setState(() => _selectedStatus = val);
    _refreshList();
  }

  Future<void> _refreshList() async {
    setState(() {
      _offset = 0;
      _hasMore = true;
      _isLoading = true;
      _error = null;
    });
    await _fetchDrivers();
  }

  Future<void> _fetchDrivers() async {
    try {
      final list = await SupabaseAdminService.instance.getAdminDriversPaginated(
        query: _searchCtrl.text.trim(),
        status: _selectedStatus,
        limit: _limit,
        offset: _offset,
      );
      if (mounted) {
        setState(() {
          if (_offset == 0) {
            _drivers = list;
          } else {
            _drivers.addAll(list);
          }
          _hasMore = list.length == _limit;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() {
      _isLoadingMore = true;
      _offset += _limit;
    });
    await _fetchDrivers();
  }

  Future<void> _deleteDriver(AppUser driver) async {
    var isDeleting = false;
    String? dialogError;

    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final email = driver.email?.trim().isNotEmpty == true
              ? driver.email!.trim()
              : 'No email on file';
          return AlertDialog(
            backgroundColor: AdminTheme.bgCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AdminTheme.border),
            ),
            title: const Text(
              'Delete Driver Account?',
              style: TextStyle(
                  color: AdminTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
            content: SizedBox(
              width: 430,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(driver.fullName,
                      style: const TextStyle(
                          color: AdminTheme.textPrimary,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(email,
                      style: const TextStyle(color: AdminTheme.textSecondary)),
                  const SizedBox(height: 16),
                  const Text(
                    'This permanently deletes the driver account, application, documents, location, sessions, and owned activities. Completed/shared rides, payments, earnings, withdrawals, and wallet history are retained or anonymized with their original status for financial integrity. Any active ride is safely cancelled and the other participant is notified. The shared TODA record is not deleted.',
                    style:
                        TextStyle(color: AdminTheme.textSecondary, height: 1.4),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 10),
                    Text(dialogError!,
                        style: const TextStyle(
                            color: AdminTheme.danger, fontSize: 12)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isDeleting
                    ? null
                    : () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: isDeleting
                    ? null
                    : () async {
                        setDialogState(() {
                          isDeleting = true;
                          dialogError = null;
                        });
                        setState(() => _deletingDriverId = driver.id);
                        try {
                          await SupabaseAdminService.instance
                              .deleteDriverAccount(driver.id);
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(true);
                          }
                        } catch (error) {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              isDeleting = false;
                              dialogError = error
                                  .toString()
                                  .replaceFirst('Bad state: ', '')
                                  .replaceFirst('StateError: ', '');
                            });
                          }
                          if (mounted) {
                            setState(() => _deletingDriverId = null);
                          }
                        }
                      },
                icon: isDeleting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.delete_forever_rounded, size: 16),
                label: Text(isDeleting ? 'Deleting...' : 'Delete Account'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.danger,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );

    if (deleted == true && mounted) {
      setState(() {
        _deletingDriverId = null;
        _drivers.removeWhere((item) => item.id == driver.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: AdminTheme.successText,
          content: Text('Driver account deleted successfully.')));
      await _refreshList();
    }
  }

  Future<bool> _approveDriver(AppUser driver) async {
    try {
      await context.read<AppState>().approveDriver(driver.id);
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AdminTheme.danger,
          content: Text('Approval failed: $error'),
        ));
      }
      return false;
    }
  }

  void _viewDriverDetails(AppUser driver) async {
    DriverProfile? profile;
    if (SupabaseService.isConfigured) {
      profile = await SupabaseService.instance.getDriverProfile(driver.id);
    }
    profile ??= await context.read<AppState>().auth.getDriverProfile(driver.id);

    if (!mounted) return;
    final resolvedProfile = profile;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth * 0.94).clamp(280.0, 580.0);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AdminTheme.border),
        ),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: AdminTheme.navyLight,
              radius: 20,
              foregroundImage: (driver.profilePhotoUrl != null &&
                      driver.profilePhotoUrl!.trim().isNotEmpty)
                  ? NetworkImage(driver.profilePhotoUrl!.trim())
                  : null,
              child: Text(
                driver.fullName.isNotEmpty
                    ? driver.fullName[0].toUpperCase()
                    : 'D',
                style: const TextStyle(
                    color: AdminTheme.greenLight,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(driver.fullName,
                      style: const TextStyle(
                          color: AdminTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  Text('Driver Account � ID: ',
                      style: const TextStyle(
                          color: AdminTheme.textMuted, fontSize: 11)),
                ],
              ),
            ),
            AdminStatusBadge(status: driver.status),
          ],
        ),
        content: SizedBox(
          width: dialogWidth,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(color: AdminTheme.borderLight),
                const SizedBox(height: 8),
                _buildInfoRow(
                    Icons.phone_rounded, 'Mobile Number', driver.mobile),
                _buildInfoRow(
                    Icons.email_rounded,
                    'Email Address',
                    (driver.email != null && driver.email!.isNotEmpty)
                        ? driver.email!
                        : 'Not linked'),
                _buildInfoRow(Icons.calendar_today_rounded, 'Registered On',
                    DateFormat('MMMM d, yyyy').format(driver.createdAt)),
                if (driver.address != null && driver.address!.isNotEmpty)
                  _buildInfoRow(
                      Icons.location_on_rounded, 'Address', driver.address!),
                const SizedBox(height: 12),
                if (resolvedProfile != null) ...[
                  const Text(
                    'VEHICLE & REGISTRATION',
                    style: TextStyle(
                        color: AdminTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AdminTheme.bgPrimary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AdminTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildVehicleRow('Vehicle Type',
                            resolvedProfile.vehicleType.name.toUpperCase()),
                        const SizedBox(height: 6),
                        _buildVehicleRow(
                            'Plate Number',
                            resolvedProfile.plateNumber.trim().isEmpty
                                ? 'Pending'
                                : resolvedProfile.plateNumber),
                        const SizedBox(height: 6),
                        _buildVehicleRow('Franchise No.', 'Not applicable'),
                        const SizedBox(height: 6),
                        _buildVehicleRow(
                            'TODA', resolvedProfile.todaId ?? 'Unassigned'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'ACCOUNT ACTIONS',
                  style: TextStyle(
                      color: AdminTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (driver.status == 'pending')
                      ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          final success = await _approveDriver(driver);
                          if (success && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    backgroundColor: AdminTheme.successText,
                                    content: Text('Driver approved.')));
                            _refreshList();
                          }
                        },
                        icon: const Icon(Icons.check_circle_rounded, size: 16),
                        label: const Text('Approve Driver'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminTheme.successText,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    if (driver.status != 'suspended')
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _suspendDriver(driver);
                        },
                        icon: const Icon(Icons.block_rounded, size: 16),
                        label: const Text('Suspend Account'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminTheme.danger,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    if (driver.status == 'suspended')
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _reactivateDriver(driver);
                        },
                        icon: const Icon(Icons.restore_rounded, size: 16),
                        label: const Text('Reactivate Account'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminTheme.successText,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(foregroundColor: AdminTheme.textMuted),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AdminTheme.slate),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AdminTheme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        color: AdminTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: AdminTheme.textMuted, fontSize: 12)),
        Text(value,
            style: const TextStyle(
                color: AdminTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  void _suspendDriver(AppUser driver) {
    // Phase 63 implementation placeholder.
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Driver suspended (Simulated for Phase 63)')));
  }

  void _reactivateDriver(AppUser driver) {
    // Phase 64 implementation placeholder.
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Driver reactivated (Simulated for Phase 64)')));
  }

  Widget _buildMobileDriverCard(BuildContext context, AppUser driver) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AdminTheme.cardDecoration(),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _viewDriverDetails(driver),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AdminTheme.navyLight,
                          radius: 18,
                          foregroundImage: (driver.profilePhotoUrl != null &&
                                  driver.profilePhotoUrl!.trim().isNotEmpty)
                              ? NetworkImage(driver.profilePhotoUrl!.trim())
                              : null,
                          child: Text(
                            driver.fullName.isNotEmpty
                                ? driver.fullName[0].toUpperCase()
                                : 'D',
                            style: const TextStyle(
                                color: AdminTheme.greenLight,
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(driver.fullName,
                                style: const TextStyle(
                                    color: AdminTheme.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            Text(driver.mobile,
                                style: const TextStyle(
                                    color: AdminTheme.textSecondary,
                                    fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    AdminStatusBadge(status: driver.status),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(color: AdminTheme.borderLight, height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Registered: ',
                      style: const TextStyle(
                          color: AdminTheme.textMuted, fontSize: 11),
                    ),
                    Row(
                      children: const [
                        Text('Manage',
                            style: TextStyle(
                                color: AdminTheme.terracotta,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                        SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded,
                            color: AdminTheme.terracotta, size: 16),
                      ],
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _deletingDriverId == driver.id
                        ? null
                        : () => _deleteDriver(driver),
                    icon: const Icon(Icons.delete_outline_rounded, size: 15),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(
                        foregroundColor: AdminTheme.danger,
                        padding: const EdgeInsets.symmetric(horizontal: 4)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AdminSectionHeader(
          title: 'Manage Driver Accounts',
          subtitle:
              'Review driver profiles, verify documents, and manage active status.',
        ),

        // 🔍 Search & Filter Controls
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: AdminTheme.cardDecoration(),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: isMobile ? double.infinity : 280,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(
                      color: AdminTheme.textPrimary, fontSize: 13),
                  decoration: AdminTheme.inputDecoration(
                    hintText: 'Search by name, mobile, email...',
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AdminTheme.slate, size: 18),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded,
                                size: 16, color: AdminTheme.slate),
                            onPressed: () {
                              _searchCtrl.clear();
                              _refreshList();
                            })
                        : null,
                  ),
                ),
              ),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AdminTheme.bgPrimary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AdminTheme.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedStatus,
                    dropdownColor: AdminTheme.bgCard,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AdminTheme.slate),
                    style: const TextStyle(
                        color: AdminTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                    items: const [
                      DropdownMenuItem(
                          value: 'all', child: Text('All Statuses')),
                      DropdownMenuItem(
                          value: 'approved', child: Text('Approved')),
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(
                          value: 'pending', child: Text('Pending (Review)')),
                      DropdownMenuItem(
                          value: 'rejected', child: Text('Rejected')),
                      DropdownMenuItem(
                          value: 'suspended', child: Text('Suspended')),
                      DropdownMenuItem(
                          value: 'restricted', child: Text('Restricted')),
                    ],
                    onChanged: _onStatusChanged,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 📋 Drivers List / Table
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
                child: CircularProgressIndicator(color: AdminTheme.terracotta)),
          )
        else if (_error != null)
          Container(
            decoration: AdminTheme.cardDecoration(),
            padding: const EdgeInsets.all(40),
            child: AdminEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Error Loading Drivers',
              subtitle: _error,
              action: ElevatedButton.icon(
                onPressed: _refreshList,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.terracotta,
                    foregroundColor: Colors.white),
              ),
            ),
          )
        else if (_drivers.isEmpty)
          Container(
            decoration: AdminTheme.cardDecoration(),
            padding: const EdgeInsets.all(40),
            child: const AdminEmptyState(
              icon: Icons.people_outline_rounded,
              title: 'No Drivers Found',
              subtitle:
                  'No driver records match your current filter or search terms.',
            ),
          )
        else ...[
          if (isMobile)
            Column(
              children: _drivers
                  .map((driver) => _buildMobileDriverCard(context, driver))
                  .toList(),
            )
          else
            Container(
              decoration: AdminTheme.cardDecoration(),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor:
                      WidgetStateProperty.all(AdminTheme.bgSecondary),
                  horizontalMargin: 16,
                  columnSpacing: 24,
                  columns: const [
                    DataColumn(
                        label: Text('DRIVER',
                            style: TextStyle(
                                color: AdminTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('MOBILE',
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
                        label: Text('REGISTERED',
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
                  rows: _drivers.map((driver) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AdminTheme.navyLight,
                                radius: 14,
                                foregroundImage:
                                    (driver.profilePhotoUrl != null &&
                                            driver.profilePhotoUrl!
                                                .trim()
                                                .isNotEmpty)
                                        ? NetworkImage(
                                            driver.profilePhotoUrl!.trim())
                                        : null,
                                child: Text(
                                  driver.fullName.isNotEmpty
                                      ? driver.fullName[0].toUpperCase()
                                      : 'D',
                                  style: const TextStyle(
                                      color: AdminTheme.greenLight,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(driver.fullName,
                                  style: const TextStyle(
                                      color: AdminTheme.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        DataCell(Text(driver.mobile,
                            style: const TextStyle(
                                color: AdminTheme.textSecondary,
                                fontSize: 12))),
                        DataCell(AdminStatusBadge(status: driver.status)),
                        DataCell(Text(
                            DateFormat('MMM d, yyyy').format(driver.createdAt),
                            style: const TextStyle(
                                color: AdminTheme.textMuted, fontSize: 12))),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _viewDriverDetails(driver),
                                icon: const Icon(Icons.manage_accounts_outlined,
                                    size: 14),
                                label: const Text('Manage'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AdminTheme.navyLight,
                                  foregroundColor: AdminTheme.textPrimary,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  textStyle: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: _deletingDriverId == driver.id
                                    ? null
                                    : () => _deleteDriver(driver),
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 14),
                                label: const Text('Delete'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AdminTheme.danger,
                                  side: const BorderSide(
                                      color: AdminTheme.danger),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  textStyle: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          if (_hasMore)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: _isLoadingMore
                    ? const CircularProgressIndicator(
                        color: AdminTheme.terracotta)
                    : ElevatedButton.icon(
                        onPressed: _loadMore,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        label: const Text('Load More'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminTheme.navyLight,
                          foregroundColor: AdminTheme.textPrimary,
                        ),
                      ),
              ),
            ),
        ],
      ],
    );
  }
}

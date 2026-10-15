import 'dart:async';
import '../../../services/supabase/admin_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/app_user.dart';
import '../admin_theme.dart';
import '../widgets/admin_widgets.dart';

/// Module 5: Manage Passenger Accounts — Search, profile review, ride history, suspend/reactivate accounts.
class AdminPassengersView extends StatefulWidget {
  const AdminPassengersView({super.key});

  @override
  State<AdminPassengersView> createState() => _AdminPassengersViewState();
}

class _AdminPassengersViewState extends State<AdminPassengersView> {
  final _searchCtrl = TextEditingController();
  String _selectedStatus = 'all';

  List<AppUser> _passengers = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  Timer? _debounce;
  String? _deletingPassengerId;

  int _offset = 0;
  final int _limit = 50;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetchPassengers();
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
    await _fetchPassengers();
  }

  Future<void> _fetchPassengers() async {
    try {
      final list =
          await SupabaseAdminService.instance.getAdminPassengersPaginated(
        query: _searchCtrl.text.trim(),
        status: _selectedStatus,
        limit: _limit,
        offset: _offset,
      );
      if (mounted) {
        setState(() {
          if (_offset == 0) {
            _passengers = list;
          } else {
            _passengers.addAll(list);
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
    await _fetchPassengers();
  }

  Future<void> _deletePassenger(AppUser user) async {
    var isDeleting = false;
    String? dialogError;

    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final email = user.email?.trim().isNotEmpty == true
              ? user.email!.trim()
              : 'No email on file';
          return AlertDialog(
            backgroundColor: AdminTheme.bgCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AdminTheme.border),
            ),
            title: const Text(
              'Delete Passenger Account?',
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
                  Text(user.fullName,
                      style: const TextStyle(
                          color: AdminTheme.textPrimary,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(email,
                      style: const TextStyle(color: AdminTheme.textSecondary)),
                  const SizedBox(height: 16),
                  const Text(
                    'This permanently deletes the passenger account and its owned, deletable activities. Completed/shared rides, payments, and wallet history are retained or anonymized with their original status for financial integrity. Any active ride is safely cancelled and the other participant is notified.',
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
                        setState(() => _deletingPassengerId = user.id);
                        try {
                          await SupabaseAdminService.instance
                              .deletePassengerAccount(user.id);
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
                            setState(() => _deletingPassengerId = null);
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
        _deletingPassengerId = null;
        _passengers.removeWhere((item) => item.id == user.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: AdminTheme.successText,
          content: Text('Passenger account deleted successfully.')));
      await _refreshList();
    }
  }

  void _viewPassengerProfile(AppUser user) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth * 0.94).clamp(280.0, 550.0);

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
              child: Text(
                user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'P',
                style: const TextStyle(
                    color: AdminTheme.terracotta,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.fullName,
                      style: const TextStyle(
                          color: AdminTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  Text('Passenger Account � ID: ',
                      style: const TextStyle(
                          color: AdminTheme.textMuted, fontSize: 11)),
                ],
              ),
            ),
            AdminStatusBadge(status: user.status),
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
                    Icons.phone_rounded, 'Mobile Number', user.mobile),
                _buildInfoRow(
                    Icons.email_rounded,
                    'Email Address',
                    (user.email != null && user.email!.isNotEmpty)
                        ? user.email!
                        : 'Not linked'),
                _buildInfoRow(Icons.verified_user_rounded, 'Email Verified',
                    user.emailVerified ? 'Yes (Verified)' : 'No (Pending)'),
                _buildInfoRow(Icons.calendar_today_rounded, 'Registered On',
                    DateFormat('MMMM d, yyyy').format(user.createdAt)),
                if (user.address != null && user.address!.isNotEmpty)
                  _buildInfoRow(
                      Icons.location_on_rounded, 'Address', user.address!),
                const SizedBox(height: 16),
                const Text(
                  'PASSENGER RIDE HISTORY',
                  style: TextStyle(
                      color: AdminTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AdminTheme.navyLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AdminTheme.border),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.history_rounded,
                          color: AdminTheme.slate, size: 28),
                      const SizedBox(height: 8),
                      const Text(
                        'Ride history query optimized for lazy loading.\nWill be implemented in phase 61.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AdminTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
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

  Widget _buildMobilePassengerCard(BuildContext context, AppUser user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AdminTheme.cardDecoration(),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _viewPassengerProfile(user),
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
                          child: Text(
                            user.fullName.isNotEmpty
                                ? user.fullName[0].toUpperCase()
                                : 'P',
                            style: const TextStyle(
                                color: AdminTheme.terracotta,
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.fullName,
                                style: const TextStyle(
                                    color: AdminTheme.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            Text(user.mobile,
                                style: const TextStyle(
                                    color: AdminTheme.textSecondary,
                                    fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    AdminStatusBadge(status: user.status),
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
                        Text('View Profile',
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
                    onPressed: _deletingPassengerId == user.id
                        ? null
                        : () => _deletePassenger(user),
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
          title: 'Manage Passenger Accounts',
          subtitle:
              'Search passenger profiles, inspect trip activity, and manage account statuses.',
        ),

        // ?? Search & Filter Controls
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
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(
                          value: 'pending', child: Text('Pending')),
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

        // ?? Passenger Accounts List / Table
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
              title: 'Error Loading Passengers',
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
        else if (_passengers.isEmpty)
          Container(
            decoration: AdminTheme.cardDecoration(),
            padding: const EdgeInsets.all(40),
            child: const AdminEmptyState(
              icon: Icons.people_outline_rounded,
              title: 'No Passengers Found',
              subtitle:
                  'No passenger records match your current filter or search terms.',
            ),
          )
        else ...[
          if (isMobile)
            Column(
              children: _passengers
                  .map((user) => _buildMobilePassengerCard(context, user))
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
                        label: Text('PASSENGER',
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
                        label: Text('EMAIL',
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
                        label: Text('EMAIL VERIFIED',
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
                  rows: _passengers.map((user) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AdminTheme.navyLight,
                                radius: 14,
                                child: Text(
                                  user.fullName.isNotEmpty
                                      ? user.fullName[0].toUpperCase()
                                      : 'P',
                                  style: const TextStyle(
                                      color: AdminTheme.terracotta,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(user.fullName,
                                  style: const TextStyle(
                                      color: AdminTheme.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        DataCell(Text(user.mobile,
                            style: const TextStyle(
                                color: AdminTheme.textSecondary,
                                fontSize: 12))),
                        DataCell(Text(
                            (user.email != null && user.email!.isNotEmpty)
                                ? user.email!
                                : '—',
                            style: const TextStyle(
                                color: AdminTheme.textMuted, fontSize: 12))),
                        DataCell(AdminStatusBadge(status: user.status)),
                        DataCell(
                          user.emailVerified
                              ? const Text('Verified',
                                  style: TextStyle(
                                      color: AdminTheme.successText,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600))
                              : const Text('Unverified',
                                  style: TextStyle(
                                      color: AdminTheme.textMuted,
                                      fontSize: 12)),
                        ),
                        DataCell(Text(
                            DateFormat('MMM d, yyyy').format(user.createdAt),
                            style: const TextStyle(
                                color: AdminTheme.textMuted, fontSize: 12))),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _viewPassengerProfile(user),
                                icon: const Icon(Icons.account_circle_outlined,
                                    size: 14),
                                label: const Text('Profile'),
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
                                onPressed: _deletingPassengerId == user.id
                                    ? null
                                    : () => _deletePassenger(user),
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

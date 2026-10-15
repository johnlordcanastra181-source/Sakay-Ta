import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/report_model.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import 'admin_theme.dart';
import 'views/admin_accounts_view.dart';
import 'views/admin_profile_view.dart';
import 'views/analytics_view.dart';
import 'views/driver_verification_view.dart';
import 'views/drivers_view.dart';
import 'views/overview_view.dart';
import 'views/fare_matrix_view.dart';
import 'views/passengers_view.dart';
import 'views/payments_view.dart';
import 'views/reports_view.dart';
import 'views/rides_view.dart';
import 'views/todas_view.dart';
import 'widgets/admin_widgets.dart';

/// Responsive Web Admin Shell hosting all dashboard modules.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.onLogout});
  final VoidCallback onLogout;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedTabIndex = 0;
  bool _sidebarCollapsed = false;
  Timer? _clockTimer;
  final ValueNotifier<String> _currentTime = ValueNotifier('');
  final Set<int> _loadedTabs = {0};

  // Lazy streams — only created when the user first visits a tab that needs
  // them. This prevents SQLite / Firestore queries on initial load.
  Stream<int>? _reportCount;
  Stream<int>? _applicationCount;

  Stream<int> _getReportCount() {
    _reportCount ??= context
        .read<AppState>()
        .reportsStream(status: ReportStatus.pending)
        .map((reports) => reports.length)
        .asBroadcastStream();
    return _reportCount!;
  }

  Stream<int> _getApplicationCount() {
    _applicationCount ??= context
        .read<AppState>()
        .pendingDriverApplicationsStream()
        .map((applications) => applications.length)
        .asBroadcastStream();
    return _applicationCount!;
  }

  final List<String> _tabTitles = [
    'Overview',
    'Monitor Rides',
    'Manage Reports',
    'Passengers',
    'Drivers',
    'Verify Drivers',
    'Analytics',
    'Payments',
    'TODAs',
    'Fare Matrix',
    'Admin Accounts',
    'Account & Security',
  ];

  @override
  void initState() {
    super.initState();
    _updateClock();
    _clockTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
  }

  void _updateClock() {
    if (mounted) {
      _currentTime.value =
          DateFormat('EEE, MMM d • h:mm:ss a').format(DateTime.now());
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _currentTime.dispose();
    super.dispose();
  }

  void _navigateToTab(int index) {
    if (_selectedTabIndex != index || !_loadedTabs.contains(index)) {
      setState(() {
        _selectedTabIndex = index;
        _loadedTabs.add(index);
      });
    }
  }

  Widget _buildSelectedView([int? index]) {
    final tabIndex = index ?? _selectedTabIndex;
    switch (tabIndex) {
      case 0:
        return AdminOverviewView(onNavigateTab: _navigateToTab);
      case 1:
        return const AdminRidesView();
      case 2:
        return const AdminReportsView();
      case 3:
        return const AdminPassengersView();
      case 4:
        return const AdminDriversView();
      case 5:
        return const AdminDriverVerificationView();
      case 6:
        return const AdminAnalyticsView();
      case 7:
        return const AdminPaymentsView();
      case 8:
        return const AdminTodasView();
      case 9:
        return const AdminFareMatrixView();
      case 10:
        final user = context.watch<AppState>().currentUser;
        if (user?.isSuperAdmin != true) {
          return _buildAccessDeniedView();
        }
        return const AdminAccountsView();
      case 11:
        return AdminProfileView(onLogout: widget.onLogout);
      default:
        return AdminOverviewView(onNavigateTab: _navigateToTab);
    }
  }

  Widget _buildAccessDeniedView() {
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
              'Access Restricted',
              style: TextStyle(
                color: AdminTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Only Super Administrators have authority to manage administrator accounts.\nContact your Super Administrator if you require access.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AdminTheme.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _navigateToTab(0),
              icon: const Icon(Icons.dashboard_rounded, size: 18),
              label: const Text('Return to Overview'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.terracotta,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    final app = context.watch<AppState>();
    final user = app.currentUser;
    final adminName = user?.fullName ?? 'Administrator';

    if (isMobile) {
      return _buildMobileShell(context, app, adminName);
    }

    return _buildDesktopShell(context, app, adminName);
  }

  // ── Dedicated Android / Mobile Shell ─────────────────────────

  Widget _buildMobileShell(
      BuildContext context, AppState app, String adminName) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AdminTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: AdminTheme.bgSecondary,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded,
              color: AdminTheme.textPrimary, size: 24),
          tooltip: 'Open Navigation Drawer',
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: AdminTheme.navy,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.electric_rickshaw_rounded,
                  color: AdminTheme.gold, size: 17),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _tabTitles[_selectedTabIndex],
                style: const TextStyle(
                  color: AdminTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AdminTheme.bgInput,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AdminTheme.borderLight),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: SupabaseService.isConfigured
                        ? AdminTheme.successText
                        : AdminTheme.warningText,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  SupabaseService.isConfigured ? 'Live' : 'Local',
                  style: const TextStyle(
                      color: AdminTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: CircleAvatar(
              backgroundColor: AdminTheme.terracotta,
              radius: 14,
              child: Text(
                adminName.isNotEmpty ? adminName[0].toUpperCase() : 'A',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
            tooltip: 'Administrator Settings & Profile',
            onPressed: () => _navigateToTab(11),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AdminTheme.borderLight, height: 1),
        ),
      ),
      drawer: _buildAndroidDrawer(context, app, adminName),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            for (final tabIndex in _loadedTabs)
              Offstage(
                offstage: _selectedTabIndex != tabIndex,
                child: TickerMode(
                  enabled: _selectedTabIndex == tabIndex,
                  child: SingleChildScrollView(
                    key: PageStorageKey('admin-tab-mobile-$tabIndex'),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    child: _buildSelectedView(tabIndex),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: _buildAndroidBottomNav(app),
    );
  }

  Widget _buildAndroidDrawer(
      BuildContext context, AppState app, String adminName) {
    return Drawer(
      backgroundColor: AdminTheme.bgSecondary,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 44, 16, 16),
            decoration: const BoxDecoration(
              color: AdminTheme.bgCard,
              border: Border(bottom: BorderSide(color: AdminTheme.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AdminTheme.navy,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.electric_rickshaw_rounded,
                          color: AdminTheme.gold, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sakay Ta',
                          style: TextStyle(
                            color: AdminTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'ADMIN PORTAL · ANDROID',
                          style: TextStyle(
                            color: AdminTheme.terracotta,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AdminTheme.slate, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AdminTheme.bgInput,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AdminTheme.borderLight),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AdminTheme.terracotta,
                        radius: 16,
                        child: Text(
                          adminName.isNotEmpty
                              ? adminName[0].toUpperCase()
                              : 'A',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              adminName,
                              style: const TextStyle(
                                  color: AdminTheme.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              app.currentUser?.isSuperAdmin == true
                                  ? 'Super Administrator'
                                  : 'Administrator',
                              style: const TextStyle(
                                  color: AdminTheme.gold, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              children: [
                _buildDrawerItem(0, Icons.dashboard_rounded, 'Overview'),
                _buildDrawerItem(1, Icons.route_rounded, 'Monitor Rides'),
                _buildDrawerItem(
                  2,
                  Icons.report_problem_rounded,
                  'Manage Reports',
                  badgeStream: _getReportCount(),
                ),
                _buildDrawerItem(3, Icons.people_alt_rounded, 'Passengers'),
                _buildDrawerItem(4, Icons.drive_eta_rounded, 'Drivers'),
                _buildDrawerItem(
                  5,
                  Icons.how_to_reg_rounded,
                  'Verify Drivers',
                  badgeStream: _getApplicationCount(),
                ),
                _buildDrawerItem(6, Icons.insights_rounded, 'Analytics'),
                _buildDrawerItem(7, Icons.payments_rounded, 'Payments'),
                _buildDrawerItem(8, Icons.groups_rounded, 'TODAs Registry'),
                _buildDrawerItem(9, Icons.price_change_rounded, 'Fare Matrix'),
                const Divider(color: AdminTheme.borderLight, height: 16),
                if (app.currentUser?.isSuperAdmin == true)
                  _buildDrawerItem(
                      10, Icons.admin_panel_settings_rounded, 'Admin Accounts'),
                _buildDrawerItem(
                    11, Icons.manage_accounts_rounded, 'Settings & Profile'),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AdminTheme.borderLight)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      final confirm = await showAdminConfirmDialog(
                        context: context,
                        title: 'Sign Out',
                        message:
                            'Are you sure you want to sign out of the Admin Portal?',
                        confirmText: 'Sign Out',
                      );
                      if (confirm == true) {
                        widget.onLogout();
                      }
                    },
                    icon: const Icon(Icons.logout_rounded,
                        size: 16, color: AdminTheme.dangerText),
                    label: const Text('Sign Out of Admin Portal',
                        style: TextStyle(
                            color: AdminTheme.dangerText,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    int index,
    IconData icon,
    String label, {
    Stream<int>? badgeStream,
  }) {
    final isSelected = _selectedTabIndex == index;

    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        _navigateToTab(index);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? AdminTheme.navyLight : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AdminTheme.terracotta : AdminTheme.slate,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? AdminTheme.textPrimary : AdminTheme.slate,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (badgeStream != null)
              StreamBuilder<int>(
                stream: badgeStream,
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  if (count <= 0) return const SizedBox.shrink();
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AdminTheme.danger,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAndroidBottomNav(AppState app) {
    int bottomNavIndex = 4;
    if (_selectedTabIndex == 0) bottomNavIndex = 0;
    if (_selectedTabIndex == 1) bottomNavIndex = 1;
    if (_selectedTabIndex == 2) bottomNavIndex = 2;
    if (_selectedTabIndex == 4) bottomNavIndex = 3;

    return Container(
      decoration: const BoxDecoration(
        color: AdminTheme.bgSecondary,
        border: Border(top: BorderSide(color: AdminTheme.borderLight)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildBottomNavItem(
              index: 0,
              icon: Icons.dashboard_rounded,
              label: 'Overview',
              isSelected: bottomNavIndex == 0,
              onTap: () => _navigateToTab(0),
            ),
            _buildBottomNavItem(
              index: 1,
              icon: Icons.route_rounded,
              label: 'Rides',
              isSelected: bottomNavIndex == 1,
              onTap: () => _navigateToTab(1),
            ),
            _buildBottomNavItem(
              index: 2,
              icon: Icons.report_problem_rounded,
              label: 'Reports',
              isSelected: bottomNavIndex == 2,
              badgeStream: _getReportCount(),
              onTap: () => _navigateToTab(2),
            ),
            _buildBottomNavItem(
              index: 3,
              icon: Icons.drive_eta_rounded,
              label: 'Drivers',
              isSelected: bottomNavIndex == 3,
              onTap: () => _navigateToTab(4),
            ),
            _buildBottomNavItem(
              index: 4,
              icon: Icons.menu_rounded,
              label: 'Menu',
              isSelected: bottomNavIndex == 4,
              badgeStream: _getApplicationCount(),
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Stream<int>? badgeStream,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected ? AdminTheme.terracotta : AdminTheme.slate,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? AdminTheme.terracotta
                        : AdminTheme.textMuted,
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (badgeStream != null)
              Positioned(
                top: -2,
                right: -4,
                child: StreamBuilder<int>(
                  stream: badgeStream,
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    if (count <= 0) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AdminTheme.danger,
                        shape: BoxShape.circle,
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Desktop Shell (Sidebar + Header) ─────────────────────────

  Widget _buildDesktopShell(
      BuildContext context, AppState app, String adminName) {
    return Scaffold(
      backgroundColor: AdminTheme.bgPrimary,
      body: Row(
        children: [
          // ── Sidebar Navigation ──────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _sidebarCollapsed ? 76 : 240,
            decoration: const BoxDecoration(
              color: AdminTheme.bgSecondary,
              border: Border(right: BorderSide(color: AdminTheme.border)),
            ),
            child: Column(
              children: [
                // Brand Header
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: const BoxDecoration(
                    border: Border(
                        bottom: BorderSide(color: AdminTheme.borderLight)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: AdminTheme.navy,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.electric_rickshaw_rounded,
                            color: AdminTheme.gold, size: 20),
                      ),
                      if (!_sidebarCollapsed) ...[
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sakay Ta',
                                style: TextStyle(
                                  color: AdminTheme.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              Text(
                                'ADMIN PORTAL',
                                style: TextStyle(
                                  color: AdminTheme.terracotta,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Admin Profile Pill
                if (!_sidebarCollapsed) ...[
                  Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AdminTheme.bgCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AdminTheme.borderLight),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AdminTheme.terracotta,
                          radius: 16,
                          child: Text(
                            adminName.isNotEmpty
                                ? adminName[0].toUpperCase()
                                : 'A',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                adminName,
                                style: const TextStyle(
                                    color: AdminTheme.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                app.currentUser?.isSuperAdmin == true
                                    ? 'Super Administrator'
                                    : 'Administrator',
                                style: const TextStyle(
                                    color: AdminTheme.gold, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else
                  const SizedBox(height: 12),

                // Navigation Items
                Expanded(
                  child: ListView(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    children: [
                      _buildNavItem(0, Icons.dashboard_rounded, 'Overview'),
                      _buildNavItem(1, Icons.route_rounded, 'Monitor Rides'),
                      _buildNavItem(
                        2,
                        Icons.report_problem_rounded,
                        'Manage Reports',
                        badgeStream: _getReportCount(),
                      ),
                      _buildNavItem(3, Icons.people_alt_rounded, 'Passengers'),
                      _buildNavItem(4, Icons.drive_eta_rounded, 'Drivers'),
                      _buildNavItem(
                        5,
                        Icons.how_to_reg_rounded,
                        'Verify Drivers',
                        badgeStream: _getApplicationCount(),
                      ),
                      _buildNavItem(6, Icons.insights_rounded, 'Analytics'),
                      _buildNavItem(7, Icons.payments_rounded, 'Payments'),
                      _buildNavItem(8, Icons.groups_rounded, 'TODAs'),
                      _buildNavItem(
                          9, Icons.price_change_rounded, 'Fare Matrix'),
                      const Divider(color: AdminTheme.borderLight, height: 16),
                      if (app.currentUser?.isSuperAdmin == true)
                        _buildNavItem(10, Icons.admin_panel_settings_rounded,
                            'Admin Accounts'),
                      _buildNavItem(
                          11, Icons.manage_accounts_rounded, 'Settings'),
                    ],
                  ),
                ),

                // Sidebar Collapse Toggle & Sign Out
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    border:
                        Border(top: BorderSide(color: AdminTheme.borderLight)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _sidebarCollapsed
                              ? Icons.chevron_right_rounded
                              : Icons.chevron_left_rounded,
                          color: AdminTheme.slate,
                        ),
                        tooltip: _sidebarCollapsed
                            ? 'Expand Sidebar'
                            : 'Collapse Sidebar',
                        onPressed: () => setState(
                            () => _sidebarCollapsed = !_sidebarCollapsed),
                      ),
                      if (!_sidebarCollapsed) ...[
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () async {
                            final confirm = await showAdminConfirmDialog(
                              context: context,
                              title: 'Sign Out',
                              message:
                                  'Are you sure you want to sign out of the Admin Portal?',
                              confirmText: 'Sign Out',
                            );
                            if (confirm == true) {
                              widget.onLogout();
                            }
                          },
                          icon: const Icon(Icons.logout_rounded,
                              size: 14, color: AdminTheme.dangerText),
                          label: const Text('Sign Out',
                              style: TextStyle(
                                  color: AdminTheme.dangerText, fontSize: 12)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Main Content Area ───────────────────────────────
          Expanded(
            child: Column(
              children: [
                // Top Header Bar
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: AdminTheme.bgSecondary,
                    border:
                        Border(bottom: BorderSide(color: AdminTheme.border)),
                  ),
                  child: Row(
                    children: [
                      // Breadcrumb
                      Row(
                        children: [
                          const Text('Admin Dashboard',
                              style: TextStyle(
                                  color: AdminTheme.textMuted, fontSize: 13)),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right_rounded,
                              size: 16, color: AdminTheme.textMuted),
                          const SizedBox(width: 8),
                          Text(
                            _tabTitles[_selectedTabIndex],
                            style: const TextStyle(
                                color: AdminTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Live Supabase connection status
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AdminTheme.bgInput,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AdminTheme.borderLight),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: SupabaseService.isConfigured
                                    ? AdminTheme.successText
                                    : AdminTheme.warningText,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              SupabaseService.isConfigured
                                  ? 'Supabase Live'
                                  : 'Local Database',
                              style: const TextStyle(
                                  color: AdminTheme.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Clock
                      ValueListenableBuilder<String>(
                        valueListenable: _currentTime,
                        builder: (context, value, child) => Text(value,
                            style: const TextStyle(
                                color: AdminTheme.textMuted, fontSize: 12)),
                      ),
                    ],
                  ),
                ),

                // Scrollable Page Content
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      for (final tabIndex in _loadedTabs)
                        Offstage(
                          offstage: _selectedTabIndex != tabIndex,
                          child: TickerMode(
                            enabled: _selectedTabIndex == tabIndex,
                            child: SingleChildScrollView(
                              key: PageStorageKey('admin-tab-desktop-$tabIndex'),
                              padding: const EdgeInsets.all(24),
                              child: _buildSelectedView(tabIndex),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label, {
    Stream<int>? badgeStream,
  }) {
    final isSelected = _selectedTabIndex == index;

    return InkWell(
      onTap: () => _navigateToTab(index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: EdgeInsets.symmetric(
            horizontal: _sidebarCollapsed ? 12 : 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AdminTheme.navyLight : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AdminTheme.terracotta : AdminTheme.slate,
            ),
            if (!_sidebarCollapsed) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color:
                        isSelected ? AdminTheme.textPrimary : AdminTheme.slate,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badgeStream != null)
                StreamBuilder<int>(
                  stream: badgeStream,
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    if (count <= 0) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AdminTheme.danger,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }
}

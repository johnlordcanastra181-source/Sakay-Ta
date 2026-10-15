import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';

enum NavTab { home, earnings, rides, wallet, profile, admin, more }

class PassengerNav extends StatelessWidget {
  const PassengerNav(
      {super.key,
      required this.current,
      required this.onHome,
      required this.onRides,
      required this.onProfile});
  final NavTab current;
  final VoidCallback onHome;
  final VoidCallback onRides;
  final VoidCallback onProfile;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return NavigationBar(
      selectedIndex: switch (current) {
        NavTab.home => 0,
        NavTab.rides => 1,
        _ => 2,
      },
      onDestinationSelected: (i) => switch (i) {
        0 => onHome(),
        1 => onRides(),
        _ => onProfile(),
      },
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home),
          label: l10n.loginTitle,
        ),
        NavigationDestination(
          icon: const Icon(Icons.receipt_long_outlined),
          label: l10n.ridesRideHistory,
        ),
        NavigationDestination(
          icon: const Icon(Icons.person_outline),
          selectedIcon: const Icon(Icons.person),
          label: l10n.profileTitle,
        ),
      ],
    );
  }
}

class DriverNav extends StatelessWidget {
  const DriverNav(
      {super.key,
      required this.current,
      required this.onHome,
      required this.onEarnings,
      required this.onWallet,
      required this.onPerformance});
  final NavTab current;
  final VoidCallback onHome;
  final VoidCallback onEarnings;
  final VoidCallback onWallet;
  final VoidCallback onPerformance;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return NavigationBar(
      selectedIndex: switch (current) {
        NavTab.home => 0,
        NavTab.earnings => 1,
        NavTab.wallet => 2,
        _ => 3,
      },
      onDestinationSelected: (i) => switch (i) {
        0 => onHome(),
        1 => onEarnings(),
        2 => onWallet(),
        _ => onPerformance(),
      },
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.directions_bike_outlined),
          label: l10n.roleDriver,
        ),
        NavigationDestination(
          icon: const Icon(Icons.bar_chart_outlined),
          label: l10n.earningsTitle,
        ),
        NavigationDestination(
          icon: const Icon(Icons.account_balance_wallet_outlined),
          label: l10n.walletTitle,
        ),
        NavigationDestination(
          icon: const Icon(Icons.stars_outlined),
          selectedIcon: const Icon(Icons.stars),
          label: l10n.performanceTitle,
        ),
      ],
    );
  }
}

class AdminNav extends StatelessWidget {
  const AdminNav(
      {super.key,
      required this.current,
      required this.onDashboard,
      required this.onDrivers,
      required this.onToda,
      required this.onReports});
  final NavTab current;
  final VoidCallback onDashboard;
  final VoidCallback onDrivers;
  final VoidCallback onToda;
  final VoidCallback onReports;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return NavigationBar(
      selectedIndex: switch (current) {
        NavTab.home => 0,
        NavTab.rides => 1,
        NavTab.earnings => 2,
        _ => 3,
      },
      onDestinationSelected: (i) => switch (i) {
        0 => onDashboard(),
        1 => onDrivers(),
        2 => onToda(),
        _ => onReports(),
      },
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.dashboard_outlined),
          label: l10n.adminTitle,
        ),
        NavigationDestination(
          icon: const Icon(Icons.people_outline),
          label: l10n.adminDrivers,
        ),
        NavigationDestination(
          icon: const Icon(Icons.groups_outlined),
          label: l10n.adminTodaTitle,
        ),
        NavigationDestination(
          icon: const Icon(Icons.assessment_outlined),
          label: l10n.adminReports,
        ),
      ],
    );
  }
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.online});
  final bool online;
  @override
  Widget build(BuildContext context) {
    if (online) return const SizedBox.shrink();
    return Material(
      color: AppColors.danger,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppLocalizations.of(context).offlineBody,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

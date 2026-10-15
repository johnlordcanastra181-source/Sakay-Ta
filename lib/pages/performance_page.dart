import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../main.dart';
import '../state/app_state.dart';

class PerformancePage extends StatelessWidget {
  const PerformancePage({super.key, required this.onNavigate});
  final Function(AppScreen) onNavigate;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isDark =
        app.darkMode || Theme.of(context).brightness == Brightness.dark;
    final driver = app.currentUser;

    if (driver == null || !driver.isDriver) {
      return Scaffold(
        backgroundColor: AppColors.canvasColor(isDark),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 48,
                color: AppColors.subtextColor(isDark),
              ),
              const SizedBox(height: 12),
              Text(
                'Driver access only',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor(isDark),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Please sign in as an accredited driver to view stats.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.subtextColor(isDark),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => onNavigate(AppScreen.login),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.terracotta,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.canvasColor(isDark),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkCardElevated
                              : const Color(0xFF1E2B45),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.electric_rickshaw_rounded,
                            size: 19,
                            color: Color(0xFFFFD600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Performance Stats',
                        style: TextStyle(
                          fontSize: 18.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textColor(isDark),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: driver.isOnline
                          ? const Color(0xFF22C55E)
                          : (isDark
                              ? const Color(0xFF64748B)
                              : const Color(0xFF94A3B8)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      driver.isOnline ? 'ON' : 'OFF',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'Your Performance',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textColor(isDark),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 16),
              _SummaryCard(
                title: 'Rating (${driver.ratingCount})',
                value: driver.ratingCount > 0
                    ? driver.rating.toStringAsFixed(1)
                    : 'New',
                isDark: isDark,
                icon: Icons.star_rounded,
                accent: AppColors.goldVibrant,
              ),
              const SizedBox(height: 12),
              _SummaryCard(
                title: 'Acceptance',
                value: '${driver.acceptanceRate.round()}%',
                isDark: isDark,
                icon: Icons.check_circle_rounded,
                accent: AppColors.emeraldVibrant,
              ),
              const SizedBox(height: 12),
              _SummaryCard(
                title: 'Trips this week',
                value: '${driver.totalTrips}',
                isDark: isDark,
                icon: Icons.route_rounded,
                accent: AppColors.terracottaVibrant,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 2,
        backgroundColor: AppColors.navBgColor(isDark),
        indicatorColor: isDark
            ? AppColors.goldVibrant.withValues(alpha: 0.2)
            : const Color(0xFFFEF08A).withValues(alpha: 0.5),
        onDestinationSelected: (index) {
          if (index == 0) onNavigate(AppScreen.driverHome);
          if (index == 1) onNavigate(AppScreen.wallet);
          if (index == 2) onNavigate(AppScreen.performance);
          if (index == 3) onNavigate(AppScreen.profile);
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined,
                color: AppColors.navInactiveColor(isDark)),
            selectedIcon: Icon(Icons.home_rounded,
                color:
                    isDark ? AppColors.goldVibrant : const Color(0xFF6E5600)),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined,
                color: AppColors.navInactiveColor(isDark)),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded,
                color:
                    isDark ? AppColors.goldVibrant : const Color(0xFF6E5600)),
            label: 'Wallet',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined,
                color: AppColors.navInactiveColor(isDark)),
            selectedIcon: Icon(Icons.insights_rounded,
                color:
                    isDark ? AppColors.goldVibrant : const Color(0xFF6E5600)),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded,
                color: AppColors.navInactiveColor(isDark)),
            selectedIcon: Icon(Icons.person_rounded,
                color:
                    isDark ? AppColors.goldVibrant : const Color(0xFF6E5600)),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.isDark,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String value;
  final bool isDark;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor(isDark)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.subtextColor(isDark),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textColor(isDark),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

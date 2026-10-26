import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/neumorphic_theme.dart';
import '../core/theme.dart';
import '../main.dart';
import '../state/app_state.dart';
import '../widgets/neumorphic_widgets.dart';

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
        backgroundColor: NeumorphicColors.canvas(isDark),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: NeumorphicCard(
              padding: const EdgeInsets.all(32),
              radius: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: NeumorphicDecorations.inset(
                      isDark: isDark,
                      radius: 30,
                    ),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 30,
                      color: NeumorphicColors.subtext(isDark),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Driver access only',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: NeumorphicColors.text(isDark),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Please sign in as an accredited driver to view stats.',
                    style: TextStyle(
                      fontSize: 13,
                      color: NeumorphicColors.subtext(isDark),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  NeumorphicButton(
                    text: 'Sign In',
                    accentColor: NeumorphicColors.brandPrimary,
                    onPressed: () => onNavigate(AppScreen.login),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final surfaceColor = NeumorphicColors.surface(isDark);

    return Scaffold(
      backgroundColor: NeumorphicColors.canvas(isDark),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2B45),
                          shape: BoxShape.circle,
                          boxShadow: NeumorphicDecorations.subtleShadows(isDark),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.electric_rickshaw_rounded,
                            size: 20,
                            color: Color(0xFFFFD600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Performance Stats',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: NeumorphicColors.text(isDark),
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
                          : const Color(0xFF94A3B8),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: driver.isOnline
                          ? [
                              BoxShadow(
                                color: const Color(0xFF22C55E).withValues(alpha: 0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
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
              const SizedBox(height: 24),
              Text(
                'Your Performance',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: NeumorphicColors.text(isDark),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 18),
              _SummaryCard(
                title: 'Rating (${driver.ratingCount})',
                value: driver.ratingCount > 0
                    ? driver.rating.toStringAsFixed(1)
                    : '0.0',
                isDark: isDark,
                icon: Icons.star_rounded,
                accent: isDark ? AppColors.gold : const Color(0xFFD97706),
              ),
              const SizedBox(height: 14),
              _SummaryCard(
                title: 'Acceptance',
                value: '${driver.acceptanceRate.round()}%',
                isDark: isDark,
                icon: Icons.check_circle_rounded,
                accent: isDark ? AppColors.emerald : const Color(0xFF10B981),
              ),
              const SizedBox(height: 14),
              _SummaryCard(
                title: 'Trips this week',
                value: '${driver.totalTrips}',
                isDark: isDark,
                icon: Icons.route_rounded,
                accent: NeumorphicColors.brandPrimary,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.35)
                  : const Color(0xFFA6B4C9).withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: 2,
          backgroundColor: surfaceColor,
          indicatorColor: NeumorphicColors.brandPrimary.withValues(alpha: 0.15),
          elevation: 0,
          height: 64,
          onDestinationSelected: (index) {
            if (index == 0) onNavigate(AppScreen.driverHome);
            if (index == 1) onNavigate(AppScreen.wallet);
            if (index == 2) onNavigate(AppScreen.performance);
            if (index == 3) onNavigate(AppScreen.profile);
          },
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_outlined,
                  color: NeumorphicColors.subtext(isDark)),
              selectedIcon: Icon(Icons.home_rounded,
                  color: NeumorphicColors.brandPrimary),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined,
                  color: NeumorphicColors.subtext(isDark)),
              selectedIcon: Icon(Icons.account_balance_wallet_rounded,
                  color: NeumorphicColors.brandPrimary),
              label: 'Wallet',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined,
                  color: NeumorphicColors.subtext(isDark)),
              selectedIcon: Icon(Icons.bar_chart_rounded,
                  color: NeumorphicColors.brandPrimary),
              label: 'Stats',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded,
                  color: NeumorphicColors.subtext(isDark)),
              selectedIcon: Icon(Icons.person_rounded,
                  color: NeumorphicColors.brandPrimary),
              label: 'Profile',
            ),
          ],
        ),
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
    return NeumorphicCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      radius: 18,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: NeumorphicDecorations.inset(
              isDark: isDark,
              radius: 24,
            ),
            child: Icon(icon, color: accent, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: NeumorphicColors.subtext(isDark),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: NeumorphicColors.text(isDark),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

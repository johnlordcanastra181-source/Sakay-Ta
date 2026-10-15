import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';

class PassengerBottomNav extends StatelessWidget {
  const PassengerBottomNav({
    super.key,
    required this.currentIndex,
    required this.onNavigate,
  });

  final int currentIndex;
  final Function(AppScreen) onNavigate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = AppColors.navBgColor(isDark);
    final borderColor = AppColors.navBorderColor(isDark);
    final activeColor = AppColors.navActiveColor(isDark);
    final inactiveColor = AppColors.navInactiveColor(isDark);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(
            color: borderColor,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: l10n.navHome,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () {
                  if (currentIndex != 0) onNavigate(AppScreen.passengerHome);
                },
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long_rounded,
                label: l10n.navActivity,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () {
                  if (currentIndex != 1) onNavigate(AppScreen.rides);
                },
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.account_balance_wallet_outlined,
                activeIcon: Icons.account_balance_wallet_rounded,
                label: l10n.navWallet,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () {
                  if (currentIndex != 2) onNavigate(AppScreen.wallet);
                },
              ),
              _buildNavItem(
                index: 3,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: l10n.navProfile,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () {
                  if (currentIndex != 3) onNavigate(AppScreen.profile);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required Color activeColor,
    required Color inactiveColor,
    required VoidCallback onTap,
  }) {
    final isSelected = currentIndex == index;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 22,
              color: isSelected ? activeColor : inactiveColor,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

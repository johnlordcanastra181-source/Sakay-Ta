import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../core/philippine_time.dart';
import '../l10n/app_localizations.dart';
import '../main.dart' hide Brand, Avatar, AppTop;
import '../models/app_user.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/passenger_bottom_nav.dart';
import '../widgets/user_avatar.dart';

class WalletPage extends StatelessWidget {
  const WalletPage({super.key, required this.onNavigate});
  final Function(AppScreen) onNavigate;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final user = app.currentUser;

    if (user != null && user.isDriver) {
      return _DriverWalletView(onNavigate: onNavigate, user: user);
    }

    return _PassengerWalletView(
        onNavigate: onNavigate, userId: user?.id ?? 'passenger_guest');
  }
}

class _PassengerWalletView extends StatefulWidget {
  const _PassengerWalletView({
    required this.onNavigate,
    required this.userId,
  });

  final Function(AppScreen) onNavigate;
  final String userId;

  @override
  State<_PassengerWalletView> createState() => _PassengerWalletViewState();
}

class _PassengerWalletViewState extends State<_PassengerWalletView> {
  Stream<List<RideEntry>>? _historyStream;
  String? _historyStreamKey;

  Function(AppScreen) get onNavigate => widget.onNavigate;
  String get userId => widget.userId;

  Stream<List<RideEntry>> _stableHistoryStream(AppState app) {
    if (_historyStream == null || _historyStreamKey != userId) {
      _historyStreamKey = userId;
      _historyStream = app.rideHistoryStream(status: RideStatus.completed);
    }
    return _historyStream!;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final app = context.watch<AppState>();
    final isDark =
        app.darkMode || Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.canvasColor(isDark),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.cardColor(isDark),
                border: Border(
                    bottom: BorderSide(color: AppColors.borderColor(isDark))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const SakayTaLogoIcon(size: 28),
                      const SizedBox(width: 8),
                      Text(
                        l10n.walletTitle,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textColor(isDark),
                        ),
                      ),
                    ],
                  ),
                  UserAvatar(
                    photoUrl: app.currentUser?.profilePhotoUrl,
                    name: app.currentUser?.fullName ?? 'Passenger',
                    avatarColorIndex: app.currentUser?.avatarColor ?? 0,
                    radius: 17,
                    border: Border.all(color: Colors.white, width: 2),
                    onTap: () => onNavigate(AppScreen.profile),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  // Recent Payment Receipts Stream
                  Text(
                    l10n.walletHistoryReceipts,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textColor(isDark),
                    ),
                  ),
                  const SizedBox(height: 8),

                  StreamBuilder<List<RideEntry>>(
                    stream: _stableHistoryStream(app),
                    initialData: const [],
                    builder: (ctx, snap) {
                      final rides = snap.data ?? [];
                      if (rides.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(24),
                          alignment: Alignment.center,
                          child: Text(
                            l10n.walletNoRecords,
                            style: TextStyle(
                                color: AppColors.subtextColor(isDark)),
                          ),
                        );
                      }

                      return Column(
                        children: rides.take(5).map((entry) {
                          final trip = entry.trip;
                          final dateStr = DateFormat('MMM dd, yyyy • hh:mm a')
                              .format(trip.completedAt ?? trip.createdAt);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.cardColor(isDark),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: AppColors.borderColor(isDark)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF064E3B)
                                            .withValues(alpha: 0.4)
                                        : const Color(0xFFECFDF5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    color: Color(0xFF059669),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Paid via ${trip.paymentMethod.toUpperCase()}',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textColor(isDark)),
                                      ),
                                      Text(
                                        dateStr,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color:
                                                AppColors.subtextColor(isDark)),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '₱${trip.fare.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: isDark
                                        ? const Color(0xFF34D399)
                                        : const Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: PassengerBottomNav(
        currentIndex: 2,
        onNavigate: onNavigate,
      ),
    );
  }
}

class _DriverWalletView extends StatefulWidget {
  const _DriverWalletView({
    required this.onNavigate,
    required this.user,
  });

  final Function(AppScreen) onNavigate;
  final dynamic user;

  @override
  State<_DriverWalletView> createState() => _DriverWalletViewState();
}

class _DriverWalletViewState extends State<_DriverWalletView> {
  Stream<AppUser?>? _userStream;
  Stream<List<WalletEntry>>? _transactionsStream;
  String? _streamDriverId;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final driverId = widget.user.id as String;
    if (_streamDriverId != driverId) {
      _streamDriverId = driverId;
      _userStream = app.streamUserProfile(driverId);
      _transactionsStream = app.transactionsStream();
    }
    final isDark =
        app.darkMode || Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<AppUser?>(
      stream: _userStream,
      builder: (context, userSnap) {
        final currentUser = userSnap.data ?? app.currentUser;
        final isOnline = currentUser?.isOnline ?? false;

        return StreamBuilder<List<WalletEntry>>(
          stream: _transactionsStream,
          initialData: const [],
          builder: (context, txSnap) {
            if (txSnap.hasError) {
              return Scaffold(
                backgroundColor: AppColors.canvasColor(isDark),
                body: Center(
                  child: Text(
                    'Unable to load wallet data. Check your connection.',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.subtextColor(isDark)),
                  ),
                ),
                bottomNavigationBar: _buildBottomNav(isDark),
              );
            }

            final entries = txSnap.data ?? const [];
            final cashEarnings = entries
                .where((e) =>
                    e.type == 'income' &&
                    e.method.toLowerCase().trim() == 'cash')
                .where((e) => const {'confirmed', 'completed'}
                    .contains(e.status?.toLowerCase().trim()))
                .fold<double>(0.0, (sum, e) => sum + e.amount);

            return Scaffold(
              backgroundColor: AppColors.canvasColor(isDark),
              body: SafeArea(
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  children: [
                    // Top Bar with Brand, Title, ON Status & Avatar
                    _buildTopBar(currentUser, isOnline, isDark),
                    const SizedBox(height: 20),

                    // Yellow Total Available Balance Card with Withdraw button
                    _buildTotalBalanceCard(context, app, cashEarnings, isDark),
                    const SizedBox(height: 16),
                    // Cash Earnings Breakdown removed since Total Cash Earnings is now the main card.
                    // Recent Transactions Section
                    _buildRecentTransactionsHeader(entries.length, isDark),
                    const SizedBox(height: 12),
                    _buildTransactionsList(entries, isDark),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              bottomNavigationBar: _buildBottomNav(isDark),
            );
          },
        );
      },
    );
  }

  // --- Top Bar with Sakay Ta Logo, Wallet Title, Green ON Status & Driver Avatar ---
  Widget _buildTopBar(AppUser? user, bool isOnline, bool isDark) {
    final driverProfile = context.read<AppState>().driverProfile;
    final photoUrl =
        (user?.profilePhotoUrl != null && user!.profilePhotoUrl!.isNotEmpty)
            ? user.profilePhotoUrl
            : driverProfile?.docProfile;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left: Logo and "Wallet" Title
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0xFF1E2B45),
                shape: BoxShape.circle,
              ),
              child: const Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    bottom: 2,
                    child: Icon(
                      Icons.location_on_rounded,
                      size: 24,
                      color: Color(0xFF142036),
                    ),
                  ),
                  Icon(
                    Icons.electric_rickshaw_rounded,
                    size: 19,
                    color: Color(0xFFFFD600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Wallet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textColor(isDark),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),

        // Right: Green "ON" / "OFF" status badge and driver avatar
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status Pill Badge (Matching design)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isOnline
                    ? const Color(0xFF22C55E) // Vibrant Green
                    : const Color(0xFF94A3B8), // Muted Slate
                borderRadius: BorderRadius.circular(20),
                boxShadow: isOnline
                    ? [
                        BoxShadow(
                          color:
                              const Color(0xFF22C55E).withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                isOnline ? 'ON' : 'OFF',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 12),

            UserAvatar(
              photoUrl: photoUrl,
              name: user?.fullName ?? 'Driver',
              avatarColorIndex: user?.avatarColor ?? 0,
              radius: 18,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
              onTap: () => widget.onNavigate(AppScreen.profile),
            ),
          ],
        ),
      ],
    );
  }

  // --- Total Cash Earnings Card (Massive Yellow Pastel Card) ---
  Widget _buildTotalBalanceCard(
      BuildContext context, AppState app, double balance, bool isDark) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    final formattedTotal = formatter.format(balance);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFDE68A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? AppColors.accentGold.withValues(alpha: 0.3)
              : Colors.transparent,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : const Color(0xFFD97706).withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: "TOTAL CASH EARNINGS"
          Row(
            children: [
              Icon(
                Icons.payments_rounded,
                size: 20,
                color: isDark ? AppColors.accentGold : const Color(0xFF5D4037),
              ),
              const SizedBox(width: 8),
              Text(
                'TOTAL CASH EARNINGS',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color:
                      isDark ? AppColors.accentGold : const Color(0xFF5D4037),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Large Bold Balance: ₱ 4,250.00
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '₱ ',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF2A1C0E),
                ),
              ),
              Text(
                formattedTotal,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF2A1C0E),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Recent Transactions Header (with "View All >") ---
  Widget _buildRecentTransactionsHeader(int count, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Recent Transactions',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textColor(isDark),
          ),
        ),
        GestureDetector(
          onTap: () {},
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'View All',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color:
                      isDark ? AppColors.accentGold : const Color(0xFF92400E),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: isDark ? AppColors.accentGold : const Color(0xFF92400E),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Real-Time Transactions Feed Matching Screenshot ---
  Widget _buildTransactionsList(List<WalletEntry> entries, bool isDark) {
    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.cardColor(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderColor(isDark)),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.receipt_long_rounded,
              color: Color(0xFF94A3B8),
              size: 28,
            ),
            const SizedBox(height: 10),
            Text(
              'No transactions yet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textColor(isDark),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Completed passenger rides and cash-outs will appear here.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.subtextColor(isDark),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final formatter = NumberFormat('#,##0.00', 'en_US');

    return Column(
      children: entries.map((entry) {
        final isIncome = entry.type == 'income';
        final isCash = entry.method.toLowerCase().trim() == 'cash';
        final dateStr = _formatTimestamp(entry.createdAt);

        final methodLabel =
            isIncome ? (isCash ? 'Cash' : 'Digital') : 'Cash-out';
        final statusLabel = switch (entry.status?.toLowerCase().trim()) {
          'confirmed' => 'Confirmed',
          'pending' => 'Pending',
          'refunded' => 'Refunded',
          'paid' => 'Paid',
          'processing' => 'Processing',
          'rejected' => 'Rejected',
          'failed' => 'Failed',
          'completed' => 'Completed',
          _ => null,
        };
        final subtitle = [
          dateStr,
          methodLabel,
          if (statusLabel != null) statusLabel,
        ].join(' • ');

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.cardColor(isDark),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderColor(isDark)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon Circle
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isIncome
                      ? (isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFF1F5F9))
                      : (isDark
                          ? const Color(0xFF4C0519)
                          : const Color(0xFFFFE4E6)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isIncome
                      ? (isCash
                          ? Icons.payments_outlined
                          : Icons.directions_car_rounded)
                      : Icons.store_rounded,
                  color: isIncome
                      ? (isCash
                          ? (isDark
                              ? const Color(0xFF34D399)
                              : const Color(0xFF15803D))
                          : (isDark
                              ? const Color(0xFF60A5FA)
                              : const Color(0xFF475569)))
                      : (isDark
                          ? const Color(0xFFF87171)
                          : const Color(0xFFE11D48)),
                  size: 19,
                ),
              ),
              const SizedBox(width: 12),

              // Title & Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.description,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textColor(isDark),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.subtextColor(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Trailing Amount: +₱150.00 (Teal Green) / -₱500.00 (Dark Charcoal)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${entry.amount >= 0 ? "+" : "-"}₱${formatter.format(entry.amount.abs())}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: entry.amount >= 0
                        ? (isDark
                            ? const Color(0xFF2DD4BF)
                            : const Color(0xFF0F766E))
                        : (isDark
                            ? const Color(0xFFF87171)
                            : const Color(0xFF0F172A)),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final local = PhilippineTime.toPhilippine(dt);
    final now = PhilippineTime.toPhilippine(PhilippineTime.now());
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return 'Today, ${DateFormat('h:mm a').format(local)}';
    }
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day) {
      return 'Yesterday, ${DateFormat('h:mm a').format(local)}';
    }
    return DateFormat('MMM d, h:mm a').format(local);
  }

  Widget _buildBottomNav(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navBgColor(isDark),
        border: Border(
          top: BorderSide(color: AppColors.navBorderColor(isDark), width: 1),
        ),
      ),
      child: NavigationBar(
        selectedIndex: 1, // Wallet Tab Selected
        backgroundColor: AppColors.navBgColor(isDark),
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 62,
        onDestinationSelected: (i) {
          if (i == 0) widget.onNavigate(AppScreen.driverHome);
          if (i == 1) widget.onNavigate(AppScreen.wallet);
          if (i == 2) widget.onNavigate(AppScreen.performance);
          if (i == 3) widget.onNavigate(AppScreen.profile);
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined,
                color: AppColors.navInactiveColor(isDark)),
            selectedIcon: Icon(Icons.home_rounded,
                color: AppColors.navActiveColor(isDark)),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined,
                color: AppColors.navActiveColor(isDark)),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded,
                color: AppColors.navActiveColor(isDark)),
            label: 'Wallet',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined,
                color: AppColors.navInactiveColor(isDark)),
            selectedIcon: Icon(Icons.bar_chart_rounded,
                color: AppColors.navActiveColor(isDark)),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded,
                color: AppColors.navInactiveColor(isDark)),
            selectedIcon: Icon(Icons.person_rounded,
                color: AppColors.navActiveColor(isDark)),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

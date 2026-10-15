import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/connectivity_service.dart';
import '../state/app_state.dart';

/// Top-level or in-page animated connectivity banner displaying real-time
/// network resilience state and pending offline action sync controls.
class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner>
    with SingleTickerProviderStateMixin {
  bool _showOnlineRecoveryToast = false;
  Timer? _recoveryTimer;
  ConnectionQuality _lastQuality = ConnectionQuality.online;

  @override
  void initState() {
    super.initState();
    _lastQuality = AppState.instance.connectionQuality;
  }

  @override
  void dispose() {
    _recoveryTimer?.cancel();
    super.dispose();
  }

  void _onQualityChanged(ConnectionQuality quality) {
    if (_lastQuality == ConnectionQuality.offline &&
        quality == ConnectionQuality.online) {
      // Reconnected! Show momentary success banner
      setState(() {
        _showOnlineRecoveryToast = true;
      });
      _recoveryTimer?.cancel();
      _recoveryTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _showOnlineRecoveryToast = false;
          });
        }
      });
    }
    _lastQuality = quality;
  }

  void _showOfflineHotlineModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const _OfflineTodaModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final quality = app.connectionQuality;
    final isOnline = app.isOnline;
    final pending = app.pendingSyncCount;
    final isSyncing = app.syncing;

    _onQualityChanged(quality);

    if (isOnline &&
        !app.isIntermittent &&
        pending == 0 &&
        !_showOnlineRecoveryToast &&
        !isSyncing) {
      return const SizedBox.shrink();
    }

    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData icon;
    String title;
    String message;

    if (_showOnlineRecoveryToast) {
      bgColor = const Color(0xFFECFDF5);
      borderColor = const Color(0xFF6EE7B7);
      textColor = const Color(0xFF065F46);
      icon = Icons.check_circle_outline_rounded;
      title = 'Back Online';
      message = 'All changes synced successfully.';
    } else if (isSyncing) {
      bgColor = const Color(0xFFEFF6FF);
      borderColor = const Color(0xFF93C5FD);
      textColor = const Color(0xFF1E40AF);
      icon = Icons.sync_rounded;
      title = 'Syncing…';
      message = 'Synchronizing $pending pending actions with cloud.';
    } else if (app.isOffline) {
      bgColor = const Color(0xFFFFFBEB);
      borderColor = const Color(0xFFFDE68A);
      textColor = const Color(0xFF92400E);
      icon = Icons.cloud_off_rounded;
      title = 'Offline Mode';
      message = pending > 0
          ? '$pending items saved locally. Will auto-sync when connected.'
          : 'App works offline with local maps & cache.';
    } else {
      // Intermittent / limited
      bgColor = const Color(0xFFFFF7ED);
      borderColor = const Color(0xFFFDBA74);
      textColor = const Color(0xFF9A3412);
      icon = Icons.network_check_rounded;
      title = 'Limited Connectivity';
      message = 'Low signal. Using cached routes and local storage.';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: widget.compact
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 12 : 14,
        vertical: widget.compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: borderColor.withValues(alpha: 0.4),
                  blurRadius: 4,
                ),
              ],
            ),
            child: isSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF1E40AF)),
                    ),
                  )
                : Icon(icon, size: 16, color: textColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    if (pending > 0 && !isSyncing) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: textColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$pending queued',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: textColor.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          if (pending > 0 && !isSyncing)
            TextButton(
              onPressed: () => app.flushSyncQueue(),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: textColor.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Sync Now',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
          if (app.isOffline && pending == 0)
            IconButton(
              tooltip: 'Offline TODA & SMS',
              icon:
                  Icon(Icons.phone_in_talk_rounded, size: 18, color: textColor),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _showOfflineHotlineModal(context),
            ),
        ],
      ),
    );
  }
}

/// Floating Pill widget for compact map overlay
class OfflineSyncPill extends StatelessWidget {
  const OfflineSyncPill({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.isOnline && !app.isIntermittent && app.pendingSyncCount == 0) {
      return const SizedBox.shrink();
    }

    final isOffline = app.isOffline;
    final pending = app.pendingSyncCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isOffline ? const Color(0xFF92400E) : const Color(0xFF1E3A8A),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOffline ? Icons.cloud_off_rounded : Icons.wifi_protected_setup,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 5),
          Text(
            isOffline
                ? (pending > 0 ? 'Offline ($pending queued)' : 'Offline Mode')
                : (pending > 0 ? 'Syncing ($pending)' : 'Limited Signal'),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Offline TODA & SMS Emergency Dispatch modal
class _OfflineTodaModal extends StatelessWidget {
  const _OfflineTodaModal();

  Future<void> _callNumber(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _sendSmsBooking(String phone, String todaName) async {
    final body = Uri.encodeComponent(
      'Sakay Ta Offline Booking:\nPickup: [My Current Location]\nDropoff: [Destination]\nVehicle: Tricycle / Habal-habal\n(Sent via Sakay Ta App)',
    );
    final uri = Uri.parse('sms:$phone?body=$body');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: context.read<AppState>().streamTodas(),
        builder: (context, snapshot) =>
            _buildContent(context, snapshot.data ?? const []),
      );

  Widget _buildContent(
      BuildContext context, List<Map<String, dynamic>> associations) {
    final hotlines = associations
        .where((a) => (a['contact_number'] ?? a['contactNumber'] ?? '')
            .toString()
            .trim()
            .isNotEmpty)
        .map((a) => <String, String>{
              'name': (a['name'] ?? 'TODA Association').toString(),
              'location': (a['municipality'] ?? a['city'] ?? '').toString(),
              'phone': (a['contact_number'] ?? a['contactNumber']).toString(),
              'sms': (a['contact_number'] ?? a['contactNumber']).toString(),
            })
        .toList();
    hotlines.add({
      'name': 'National Emergency Hotline',
      'location': 'Philippines Nationwide',
      'phone': '911',
      'sms': ''
    });
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.phone_in_talk,
                    color: Color(0xFFD97706), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Offline TODA & Emergency',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'Call or SMS local dispatch terminals directly without internet.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...hotlines.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name']!,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item['location']!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (item['sms']!.isNotEmpty)
                        IconButton(
                          tooltip: 'SMS Dispatch',
                          icon: const Icon(Icons.sms_outlined,
                              color: Color(0xFF2563EB), size: 20),
                          onPressed: () =>
                              _sendSmsBooking(item['sms']!, item['name']!),
                        ),
                      IconButton(
                        tooltip: 'Direct Call',
                        icon: const Icon(Icons.call_rounded,
                            color: Color(0xFF059669), size: 20),
                        onPressed: () => _callNumber(item['phone']!),
                      ),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/neumorphic_theme.dart';
import '../state/app_state.dart';
import 'neumorphic_widgets.dart';
import 'submit_report_dialog.dart';

class HelpCenterModal extends StatefulWidget {
  const HelpCenterModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const HelpCenterModal(),
    );
  }

  @override
  State<HelpCenterModal> createState() => _HelpCenterModalState();
}

class _HelpCenterModalState extends State<HelpCenterModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, String>> _faqs = [
    {
      'question': 'How are tricycle and habal-habal fares calculated?',
      'answer':
          'Fares use the active Fare Matrix stored by Sakay Ta. The configured base fare covers the included distance, then the configured per-kilometre rate applies to the remaining distance. The confirmed total is stored with the ride.',
    },
    {
      'question': 'How do I pay using GCash or Maya?',
      'answer':
          'You can link your GCash or Maya wallet under Profile > Payment Methods. Once linked, set it as your default payment method. Your fare is automatically deducted upon ride completion and a digital receipt is generated.',
    },
    {
      'question': 'Can I cancel a ride after booking?',
      'answer':
          'Yes, you can cancel an active booking before the driver arrives without penalty. Tap the "Cancel Ride" button on your Activity or Tracking screen.',
    },
    {
      'question': 'How does Sakay Ta verify TODA drivers?',
      'answer':
          'All registered drivers undergo strict document verification including Valid Driver\'s License, OR/CR, TODA Association Membership Franchise, and Barangay/Police clearances.',
    },
    {
      'question': 'What should I do if I left an item in a ride?',
      'answer':
          'Go to your Activity > History page, tap on the completed ride, and use the driver contact info or report a lost item through the Sakay Ta support hotline.',
    },
  ];

  void _callNumber(String number) async {
    final uri = Uri.parse('tel:$number');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hotline: $number')),
        );
      }
    }
  }

  void _showTicketDialog() {
    // Persists a real report to Supabase (Admin > Manage Reports).
    showSubmitReportDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isDark = app.darkMode || Theme.of(context).brightness == Brightness.dark;

    final filteredFaqs = _searchQuery.isEmpty
        ? _faqs
        : _faqs
            .where((f) =>
                f['question']!
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ||
                f['answer']!.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: NeumorphicColors.surface(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.5)
                : const Color(0xFFA6B4C9).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Help & Support Center',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: NeumorphicColors.text(isDark),
                  letterSpacing: -0.3,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: NeumorphicColors.subtext(isDark),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Search Field
          Container(
            decoration: NeumorphicDecorations.inset(
              isDark: isDark,
              radius: 14,
            ),
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(
                color: NeumorphicColors.text(isDark),
                fontSize: 14,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search help topics and FAQs...',
                hintStyle: TextStyle(
                  color: NeumorphicColors.subtext(isDark).withValues(alpha: 0.7),
                  fontSize: 13.5,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: NeumorphicColors.subtext(isDark),
                ),
                filled: false,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Contact shortcuts row
          Row(
            children: [
              Expanded(
                child: NeumorphicCard(
                  onTap: () => _callNumber('911'),
                  padding: const EdgeInsets.all(12),
                  radius: 14,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.emergency_rounded,
                          color: Color(0xFFDC2626),
                          size: 18,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Emergency (911)',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFDC2626),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NeumorphicCard(
                  onTap: () => _callNumber('09178887252'),
                  padding: const EdgeInsets.all(12),
                  radius: 14,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.phone_in_talk_rounded,
                          color: Color(0xFF059669),
                          size: 18,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Hotline Support',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF059669),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NeumorphicCard(
                  onTap: _showTicketDialog,
                  padding: const EdgeInsets.all(12),
                  radius: 14,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? NeumorphicColors.brandPrimary.withValues(alpha: 0.2)
                              : const Color(0xFFFFF7ED),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: NeumorphicColors.brandPrimary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Send Ticket',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: NeumorphicColors.brandPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Text(
            'Frequently Asked Questions',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: NeumorphicColors.text(isDark),
            ),
          ),
          const SizedBox(height: 12),

          // FAQ Accordion List
          Expanded(
            child: ListView.separated(
              itemCount: filteredFaqs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final faq = filteredFaqs[i];
                return NeumorphicCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  radius: 14,
                  child: Theme(
                    data: Theme.of(ctx).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      iconColor: NeumorphicColors.brandPrimary,
                      collapsedIconColor: NeumorphicColors.subtext(isDark),
                      title: Text(
                        faq['question']!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: NeumorphicColors.text(isDark),
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            faq['answer']!,
                            style: TextStyle(
                              fontSize: 12,
                              color: NeumorphicColors.subtext(isDark),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'submit_report_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Help & Support Center',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E1E1E),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search Field
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search help topics and FAQs...',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Contact shortcuts row
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _callNumber('911'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: const [
                        Icon(Icons.emergency_rounded,
                            color: Color(0xFFDC2626), size: 20),
                        SizedBox(height: 4),
                        Text(
                          'Emergency (911)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _callNumber('09178887252'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: const [
                        Icon(Icons.phone_in_talk_rounded,
                            color: Color(0xFF059669), size: 20),
                        SizedBox(height: 4),
                        Text(
                          'Hotline Support',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: _showTicketDialog,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: const [
                        Icon(Icons.chat_bubble_outline_rounded,
                            color: Color(0xFF4F46E5), size: 20),
                        SizedBox(height: 4),
                        Text(
                          'Send Ticket',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          const Text(
            'Frequently Asked Questions',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),

          // FAQ Accordion List
          Expanded(
            child: ListView.separated(
              itemCount: filteredFaqs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final faq = filteredFaqs[i];
                return Theme(
                  data:
                      Theme.of(ctx).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      faq['question']!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E1E1E),
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          faq['answer']!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF4B5563),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
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

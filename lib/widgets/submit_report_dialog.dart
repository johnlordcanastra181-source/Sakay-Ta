import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/report_model.dart';
import '../state/app_state.dart';

/// Shared passenger/driver report form backed by [AppState.createReport].
///
/// Keeps the original Help Center "Submit Support Ticket" look. The report is
/// saved to Supabase `public.reports` (RLS: reporter_id = auth.uid(),
/// status = 'pending') and appears in Admin → Manage Reports in realtime.
Future<void> showSubmitReportDialog(
  BuildContext context, {
  String dialogTitle = 'Submit Support Ticket',
  String initialType = ReportType.other,
  String? rideId,
  String? reportedUserId,
  String? reportedUserName,
  String? reportedUserRole,
}) {
  final app = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);
  final issueCtrl = TextEditingController();
  final messageCtrl = TextEditingController();
  var selectedType =
      ReportType.all.contains(initialType) ? initialType : ReportType.other;
  var isSubmitting = false;
  String? errorText;

  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(dialogTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (rideId != null && rideId.trim().isNotEmpty) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.directions_car_outlined,
                          size: 16, color: Color(0xFF6E5600)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ride: $rideId',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: ReportType.all
                    .map((t) => DropdownMenuItem(
                        value: t, child: Text(ReportType.displayTitle(t))))
                    .toList(),
                onChanged: isSubmitting
                    ? null
                    : (v) => setDialogState(
                        () => selectedType = v ?? ReportType.other),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: issueCtrl,
                enabled: !isSubmitting,
                decoration: const InputDecoration(
                  labelText: 'Subject / Issue',
                  hintText: 'e.g. Fare inquiry, Lost item',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageCtrl,
                enabled: !isSubmitting,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Please describe the details of your request...',
                  border: OutlineInputBorder(),
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 10),
                Text(errorText!,
                    style: const TextStyle(
                        color: Color(0xFFDC2626), fontSize: 12)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6E5600),
              foregroundColor: Colors.white,
            ),
            onPressed: isSubmitting
                ? null
                : () async {
                    final title = issueCtrl.text.trim();
                    final description = messageCtrl.text.trim();
                    if (title.isEmpty || description.isEmpty) {
                      setDialogState(() => errorText =
                          'Please enter a subject and description.');
                      return;
                    }
                    final user = app.currentUser;
                    if (user == null) {
                      setDialogState(() =>
                          errorText = 'Please sign in to submit a report.');
                      return;
                    }
                    setDialogState(() {
                      isSubmitting = true;
                      errorText = null;
                    });
                    try {
                      await app.createReport(FireReport(
                        id: 'rep_${DateTime.now().millisecondsSinceEpoch}',
                        reporterId: user.id,
                        reporterName:
                            user.fullName.isEmpty ? 'User' : user.fullName,
                        reporterRole: user.role,
                        reporterMobile:
                            user.mobile.isEmpty ? null : user.mobile,
                        reportedUserId: reportedUserId,
                        reportedUserName: reportedUserName,
                        reportedUserRole: reportedUserRole,
                        rideId: (rideId?.trim().isNotEmpty ?? false)
                            ? rideId!.trim()
                            : null,
                        type: selectedType,
                        title: title,
                        description: description,
                        status: ReportStatus.pending,
                        createdAt: DateTime.now(),
                      ));
                      if (ctx.mounted) Navigator.pop(ctx);
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Report submitted successfully! Our team will review it shortly.'),
                          backgroundColor: Color(0xFF059669),
                        ),
                      );
                    } catch (e) {
                      debugPrint('[Reports] submit failed: $e');
                      if (ctx.mounted) {
                        setDialogState(() {
                          isSubmitting = false;
                          errorText =
                              'Unable to submit report. Please try again.\n$e';
                        });
                      }
                    }
                  },
            child: isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Submit'),
          ),
        ],
      ),
    ),
  );
}


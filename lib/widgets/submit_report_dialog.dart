import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/neumorphic_theme.dart';
import '../models/report_model.dart';
import '../state/app_state.dart';
import 'neumorphic_widgets.dart';

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
  final isDark = app.darkMode || Theme.of(context).brightness == Brightness.dark;
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
        backgroundColor: NeumorphicColors.surface(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          dialogTitle,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: NeumorphicColors.text(isDark),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (rideId != null && rideId.trim().isNotEmpty) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: NeumorphicDecorations.inset(
                    isDark: isDark,
                    radius: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.directions_car_rounded,
                          size: 16,
                          color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ride: $rideId',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: NeumorphicColors.text(isDark),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                dropdownColor: NeumorphicColors.surface(isDark),
                style: TextStyle(
                  color: NeumorphicColors.text(isDark),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: 'Category',
                  labelStyle: TextStyle(
                    color: NeumorphicColors.subtext(isDark),
                    fontSize: 13,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: NeumorphicColors.brandPrimary,
                      width: 1.5,
                    ),
                  ),
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
              const SizedBox(height: 14),
              TextField(
                controller: issueCtrl,
                enabled: !isSubmitting,
                style: TextStyle(color: NeumorphicColors.text(isDark)),
                decoration: InputDecoration(
                  labelText: 'Subject / Issue',
                  hintText: 'e.g. Fare inquiry, Lost item',
                  labelStyle: TextStyle(
                    color: NeumorphicColors.subtext(isDark),
                    fontSize: 13,
                  ),
                  hintStyle: TextStyle(
                    color: NeumorphicColors.subtext(isDark).withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: NeumorphicColors.brandPrimary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: messageCtrl,
                enabled: !isSubmitting,
                maxLines: 3,
                style: TextStyle(color: NeumorphicColors.text(isDark)),
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Please describe the details of your request...',
                  labelStyle: TextStyle(
                    color: NeumorphicColors.subtext(isDark),
                    fontSize: 13,
                  ),
                  hintStyle: TextStyle(
                    color: NeumorphicColors.subtext(isDark).withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: NeumorphicColors.brandPrimary,
                      width: 1.5,
                    ),
                  ),
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
            child: Text(
              'Cancel',
              style: TextStyle(
                color: NeumorphicColors.subtext(isDark),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: 110,
            child: NeumorphicButton(
              text: 'Submit',
              height: 42,
              isLoading: isSubmitting,
              accentColor: NeumorphicColors.brandPrimary,
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
            ),
          ),
        ],
      ),
    ),
  );
}


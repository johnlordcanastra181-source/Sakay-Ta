import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/report_model.dart';
import '../../../state/app_state.dart';
import '../admin_theme.dart';
import '../widgets/admin_widgets.dart';

/// Module 3 & 4: Manage Reports & View Report Details — Incident reports, investigations, and customer support.
class AdminReportsView extends StatefulWidget {
  const AdminReportsView({super.key});

  @override
  State<AdminReportsView> createState() => _AdminReportsViewState();
}

class _AdminReportsViewState extends State<AdminReportsView> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => setState(() {}));
  }

  String _selectedStatus = 'all';
  String _selectedType = 'all';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openReportDetailsDialog(FireReport report) {
    final app = context.read<AppState>();
    final noteCtrl = TextEditingController();
    final resolutionCtrl = TextEditingController();
    String newStatus = report.status;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth * 0.94).clamp(280.0, 600.0);

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: AdminTheme.bgCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AdminTheme.border),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AdminTheme.danger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.report_problem_rounded,
                      color: AdminTheme.danger, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.title,
                        style: const TextStyle(
                          color: AdminTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Case #${report.id}  •  ${ReportType.displayTitle(report.type)}',
                        style: const TextStyle(
                            color: AdminTheme.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                AdminStatusBadge(status: report.status),
              ],
            ),
            content: SizedBox(
              width: dialogWidth,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(color: AdminTheme.borderLight),
                    const SizedBox(height: 8),

                    // Description
                    const Text('REPORT DESCRIPTION',
                        style: TextStyle(
                            color: AdminTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AdminTheme.bgInput,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AdminTheme.border),
                      ),
                      child: Text(
                        report.description,
                        style: const TextStyle(
                            color: AdminTheme.textPrimary,
                            fontSize: 13,
                            height: 1.4),
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Text('INVOLVED PARTIES',
                        style: TextStyle(
                            color: AdminTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    _buildPartyRow(
                        'Reporter',
                        '${report.reporterName} (${report.reporterRole.toUpperCase()})',
                        report.reporterMobile),
                    if (report.reportedUserName != null)
                      _buildPartyRow(
                          'Reported User',
                          '${report.reportedUserName} (${(report.reportedUserRole ?? 'User').toUpperCase()})',
                          null),
                    if (report.rideId != null && report.rideId!.isNotEmpty)
                      _buildPartyRow(
                          'Associated Ride ID', report.rideId!, null),

                    const SizedBox(height: 16),
                    const Text('INVESTIGATION NOTES LOG',
                        style: TextStyle(
                            color: AdminTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    if (report.adminNotes.isEmpty)
                      const Text('No investigation notes added yet.',
                          style: TextStyle(
                              color: AdminTheme.textMuted,
                              fontSize: 12,
                              fontStyle: FontStyle.italic))
                    else
                      ...report.adminNotes.map((note) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AdminTheme.bgSecondary,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AdminTheme.borderLight),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.sticky_note_2_outlined,
                                  size: 14, color: AdminTheme.gold),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(note,
                                    style: const TextStyle(
                                        color: AdminTheme.textPrimary,
                                        fontSize: 12)),
                              ),
                            ],
                          ),
                        );
                      }),

                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: noteCtrl,
                            style: const TextStyle(
                                color: AdminTheme.textPrimary, fontSize: 12),
                            decoration: AdminTheme.inputDecoration(
                                hintText: 'Add an investigation note...'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            if (noteCtrl.text.trim().isNotEmpty) {
                              await app.addReportNote(
                                  report.id, noteCtrl.text.trim());
                              noteCtrl.clear();
                              if (ctx.mounted) Navigator.of(ctx).pop();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminTheme.navyLight,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                          ),
                          child: const Text('Add Note',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),
                    const Text('UPDATE STATUS & RESOLUTION',
                        style: TextStyle(
                            color: AdminTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: newStatus,
                            dropdownColor: AdminTheme.bgCard,
                            style: const TextStyle(
                                color: AdminTheme.textPrimary, fontSize: 13),
                            decoration:
                                AdminTheme.inputDecoration(hintText: 'Status'),
                            items: ReportStatus.all.map((st) {
                              return DropdownMenuItem(
                                value: st,
                                child: Text(ReportStatus.displayLabel(st)),
                              );
                            }).toList(),
                            onChanged: (val) => setModalState(
                                () => newStatus = val ?? report.status),
                          ),
                        ),
                      ],
                    ),

                    if (newStatus == ReportStatus.resolved) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: resolutionCtrl,
                        maxLines: 2,
                        style: const TextStyle(
                            color: AdminTheme.textPrimary, fontSize: 12),
                        decoration: AdminTheme.inputDecoration(
                            hintText:
                                'Enter resolution summary (reimbursement, warning, etc.)...'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel',
                    style: TextStyle(color: AdminTheme.slate)),
              ),
              ElevatedButton(
                onPressed: () async {
                  await app.updateReportStatus(
                    report.id,
                    newStatus,
                    resolution: resolutionCtrl.text.trim().isNotEmpty
                        ? resolutionCtrl.text.trim()
                        : null,
                    adminName: 'Admin',
                  );
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Report updated successfully.')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.terracotta,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: const Text('Save Changes',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openCreateReportDialog(AppState app) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final reporterNameCtrl = TextEditingController(text: 'Admin Staff');
    final reportedUserCtrl = TextEditingController();
    final rideIdCtrl = TextEditingController();
    String selectedType = ReportType.safety;
    bool isSubmitting = false;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth * 0.94).clamp(280.0, 580.0);

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: AdminTheme.bgCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AdminTheme.border),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AdminTheme.terracotta.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_alert_rounded,
                      color: AdminTheme.terracotta, size: 22),
                ),
                const SizedBox(width: 12),
                const Text('File Incident Report',
                    style: TextStyle(
                        color: AdminTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            content: SizedBox(
              width: dialogWidth,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('INCIDENT DETAILS',
                        style: TextStyle(
                            color: AdminTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: titleCtrl,
                      style: const TextStyle(
                          color: AdminTheme.textPrimary, fontSize: 13),
                      decoration: AdminTheme.inputDecoration(
                          hintText: 'Report Title (e.g. Fare Dispute)'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      dropdownColor: AdminTheme.bgCard,
                      style: const TextStyle(
                          color: AdminTheme.textPrimary, fontSize: 13),
                      decoration:
                          AdminTheme.inputDecoration(hintText: 'Category'),
                      items: ReportType.all
                          .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(ReportType.displayTitle(t))))
                          .toList(),
                      onChanged: (v) => setModalState(
                          () => selectedType = v ?? ReportType.safety),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      style: const TextStyle(
                          color: AdminTheme.textPrimary, fontSize: 13),
                      decoration: AdminTheme.inputDecoration(
                          hintText: 'Detailed description of the incident...'),
                    ),
                    const SizedBox(height: 14),
                    const Text('INVOLVED PARTIES (OPTIONAL)',
                        style: TextStyle(
                            color: AdminTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: reporterNameCtrl,
                      style: const TextStyle(
                          color: AdminTheme.textPrimary, fontSize: 13),
                      decoration:
                          AdminTheme.inputDecoration(hintText: 'Reporter Name'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: reportedUserCtrl,
                      style: const TextStyle(
                          color: AdminTheme.textPrimary, fontSize: 13),
                      decoration: AdminTheme.inputDecoration(
                          hintText: 'Reported User (Passenger or Driver Name)'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: rideIdCtrl,
                      style: const TextStyle(
                          color: AdminTheme.textPrimary, fontSize: 13),
                      decoration: AdminTheme.inputDecoration(
                          hintText: 'Related Ride ID (optional)'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel',
                    style: TextStyle(color: AdminTheme.slate)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.terracotta,
                  foregroundColor: Colors.white,
                ),
                onPressed: isSubmitting ? null : () async {
                  if (titleCtrl.text.trim().isEmpty ||
                      descCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Please fill out title and description.')),
                    );
                    return;
                  }
                  final enteredRideId = rideIdCtrl.text.trim();
                  final messenger = ScaffoldMessenger.of(this.context);

                  if (enteredRideId.isNotEmpty) {
                    setModalState(() => isSubmitting = true);
                    final exists = await app.rideExists(enteredRideId);
                    if (!exists) {
                      if (ctx.mounted) setModalState(() => isSubmitting = false);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'Ride ID "$enteredRideId" was not found in the rides database. '
                            'Please verify the Ride ID or leave it empty for a general report.',
                          ),
                          backgroundColor: Colors.red.shade700,
                        ),
                      );
                      return;
                    }
                  }

                  final newReport = FireReport(
                    id: 'rep_${DateTime.now().millisecondsSinceEpoch}',
                    // Must be the authenticated admin's UUID (uuid FK column).
                    reporterId: app.currentUser?.id ?? '',
                    reporterName: reporterNameCtrl.text.trim().isNotEmpty
                        ? reporterNameCtrl.text.trim()
                        : 'Admin Staff',
                    reporterRole: 'admin',
                    reportedUserName: reportedUserCtrl.text.trim().isNotEmpty
                        ? reportedUserCtrl.text.trim()
                        : null,
                    rideId: enteredRideId.isNotEmpty ? enteredRideId : null,
                    type: selectedType,
                    title: titleCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    status: ReportStatus.pending,
                    priority: 'normal',
                    createdAt: DateTime.now(),
                  );
                  setModalState(() => isSubmitting = true);
                  try {
                    await app.createReport(newReport);
                  } catch (e) {
                    debugPrint('[Reports] admin create failed: $e');
                    if (ctx.mounted) setModalState(() => isSubmitting = false);
                    messenger.showSnackBar(SnackBar(
                      content: Text('Failed to submit report: $e'),
                      backgroundColor: Colors.red.shade700,
                    ));
                    return;
                  }
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Incident report created successfully.'),
                        backgroundColor: AdminTheme.navyLight,
                      ),
                    );
                  }
                },
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Submit Report'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMobileReportCard(
      BuildContext context, FireReport rep, AppState app) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AdminTheme.cardDecoration(),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openReportDetailsDialog(rep),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AdminTheme.bgInput,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AdminTheme.borderLight),
                          ),
                          child: Text(
                            ReportType.displayTitle(rep.type),
                            style: const TextStyle(
                              color: AdminTheme.terracotta,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          rep.id.length > 10
                              ? '${rep.id.substring(0, 10)}…'
                              : rep.id,
                          style: const TextStyle(
                              color: AdminTheme.textMuted,
                              fontFamily: 'monospace',
                              fontSize: 10),
                        ),
                      ],
                    ),
                    AdminStatusBadge(status: rep.status),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  rep.title,
                  style: const TextStyle(
                      color: AdminTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  rep.description,
                  style: const TextStyle(
                      color: AdminTheme.textSecondary, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                const Divider(color: AdminTheme.borderLight, height: 1),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'By: ${rep.reporterName}',
                      style: const TextStyle(
                          color: AdminTheme.slateLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w500),
                    ),
                    Row(
                      children: [
                        Text(
                          DateFormat('MMM d, h:mm a').format(rep.createdAt),
                          style: const TextStyle(
                              color: AdminTheme.textMuted, fontSize: 10),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded,
                            color: AdminTheme.slate, size: 16),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPartyRow(String role, String name, String? mobile) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
              width: 140,
              child: Text(role,
                  style: const TextStyle(
                      color: AdminTheme.textMuted, fontSize: 12))),
          Text(name,
              style: const TextStyle(
                  color: AdminTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          if (mobile != null && mobile.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text('($mobile)',
                style: const TextStyle(
                    color: AdminTheme.textSecondary, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AdminSectionHeader(
                title: 'Manage Reports & Support',
                subtitle:
                    'Resolve customer incident reports, driver disputes, lost items, and safety investigations.',
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _openCreateReportDialog(app),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(isMobile ? 'Report' : 'File Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.terracotta,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                textStyle:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
          ],
        ),

        // ── Controls & Filter Bar ────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: AdminTheme.cardDecoration(),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: isMobile ? double.infinity : 280,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(
                      color: AdminTheme.textPrimary, fontSize: 13),
                  decoration: AdminTheme.inputDecoration(
                    hintText: 'Search title, user, ride ID...',
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AdminTheme.slate, size: 18),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded,
                                size: 16, color: AdminTheme.slate),
                            onPressed: () =>
                                setState(() => _searchCtrl.clear()),
                          )
                        : null,
                  ),
                ),
              ),
              DropdownButtonHideUnderline(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: AdminTheme.bgInput,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AdminTheme.border),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedStatus,
                    dropdownColor: AdminTheme.bgCard,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AdminTheme.slate),
                    style: const TextStyle(
                        color: AdminTheme.textPrimary, fontSize: 13),
                    items: const [
                      DropdownMenuItem(
                          value: 'all', child: Text('All Statuses')),
                      DropdownMenuItem(
                          value: ReportStatus.pending,
                          child: Text('Pending Review')),
                      DropdownMenuItem(
                          value: ReportStatus.underInvestigation,
                          child: Text('Under Investigation')),
                      DropdownMenuItem(
                          value: ReportStatus.resolved,
                          child: Text('Resolved')),
                      DropdownMenuItem(
                          value: ReportStatus.dismissed,
                          child: Text('Dismissed')),
                    ],
                    onChanged: (val) =>
                        setState(() => _selectedStatus = val ?? 'all'),
                  ),
                ),
              ),
              DropdownButtonHideUnderline(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: AdminTheme.bgInput,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AdminTheme.border),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedType,
                    dropdownColor: AdminTheme.bgCard,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AdminTheme.slate),
                    style: const TextStyle(
                        color: AdminTheme.textPrimary, fontSize: 13),
                    items: [
                      const DropdownMenuItem(
                          value: 'all', child: Text('All Categories')),
                      ...ReportType.all.map((t) => DropdownMenuItem(
                          value: t, child: Text(ReportType.displayTitle(t)))),
                    ],
                    onChanged: (val) =>
                        setState(() => _selectedType = val ?? 'all'),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Reports List / Table ────────────────────────────
        AdminDataStreamBuilder<List<FireReport>>(
          key: ValueKey(
              'reports|$_selectedStatus|$_selectedType|${_searchCtrl.text}'),
          section: 'reports_list',
          streamFactory: () => app.reportsStream(
            status: _selectedStatus == 'all' ? null : _selectedStatus,
            type: _selectedType == 'all' ? null : _selectedType,
            searchQuery: _searchCtrl.text,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                    child: CircularProgressIndicator(
                        color: AdminTheme.terracotta)),
              );
            }

            final reports = snapshot.data ?? [];
            if (reports.isEmpty) {
              return Container(
                decoration: AdminTheme.cardDecoration(),
                padding: const EdgeInsets.all(40),
                child: const AdminEmptyState(
                  icon: Icons.assignment_turned_in_outlined,
                  title: 'No Reports Found',
                  subtitle:
                      'There are no incident or dispute reports matching the current filter criteria.',
                ),
              );
            }

            // Mobile Card View
            if (isMobile) {
              return Column(
                children: reports
                    .map((rep) => _buildMobileReportCard(context, rep, app))
                    .toList(),
              );
            }

            // Desktop Data Table View
            return Container(
              decoration: AdminTheme.cardDecoration(),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor:
                      WidgetStateProperty.all(AdminTheme.bgSecondary),
                  horizontalMargin: 16,
                  columnSpacing: 24,
                  columns: const [
                    DataColumn(
                        label: Text('CASE ID',
                            style: TextStyle(
                                color: AdminTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('CATEGORY',
                            style: TextStyle(
                                color: AdminTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('TITLE & SUMMARY',
                            style: TextStyle(
                                color: AdminTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('REPORTER',
                            style: TextStyle(
                                color: AdminTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('REPORTED USER',
                            style: TextStyle(
                                color: AdminTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('STATUS',
                            style: TextStyle(
                                color: AdminTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('SUBMITTED',
                            style: TextStyle(
                                color: AdminTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('ACTION',
                            style: TextStyle(
                                color: AdminTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                  ],
                  rows: reports.map((rep) {
                    return DataRow(
                      cells: [
                        DataCell(Text(rep.id,
                            style: const TextStyle(
                                color: AdminTheme.slateLight,
                                fontFamily: 'monospace',
                                fontSize: 12))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AdminTheme.bgInput,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AdminTheme.borderLight),
                            ),
                            child: Text(
                              ReportType.displayTitle(rep.type),
                              style: const TextStyle(
                                  color: AdminTheme.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 220),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(rep.title,
                                    style: const TextStyle(
                                        color: AdminTheme.textPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis),
                                Text(rep.description,
                                    style: const TextStyle(
                                        color: AdminTheme.textMuted,
                                        fontSize: 11),
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ),
                        DataCell(Text(rep.reporterName,
                            style: const TextStyle(
                                color: AdminTheme.textPrimary, fontSize: 12))),
                        DataCell(Text(rep.reportedUserName ?? '—',
                            style: const TextStyle(
                                color: AdminTheme.textSecondary,
                                fontSize: 12))),
                        DataCell(AdminStatusBadge(status: rep.status)),
                        DataCell(Text(
                            DateFormat('MMM d, h:mm a').format(rep.createdAt),
                            style: const TextStyle(
                                color: AdminTheme.textMuted, fontSize: 12))),
                        DataCell(
                          ElevatedButton.icon(
                            onPressed: () => _openReportDetailsDialog(rep),
                            icon:
                                const Icon(Icons.rate_review_rounded, size: 14),
                            label: const Text('Manage'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AdminTheme.terracotta,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              textStyle: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

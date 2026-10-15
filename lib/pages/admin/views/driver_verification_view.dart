import 'package:flutter/material.dart';
import '../../../models/firestore_models.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants.dart';
import '../../../models/app_user.dart';
import '../../../models/driver_profile.dart';
import '../../../state/app_state.dart';
import '../admin_theme.dart';
import '../widgets/admin_widgets.dart';

/// Module 7: Verify Driver Registration & Review Driver Documents — Verification queue, document preview, Approve/Reject.
class AdminDriverVerificationView extends StatefulWidget {
  const AdminDriverVerificationView({super.key});

  @override
  State<AdminDriverVerificationView> createState() =>
      _AdminDriverVerificationViewState();
}

class _AdminDriverVerificationViewState
    extends State<AdminDriverVerificationView> {
  int _refreshGen = 0;
  Future<List<DriverApplication>>? _rejectedHistoryFuture;
  final _rejectedSearchCtrl = TextEditingController();
  String _rejectedSortOrder = 'newest';
  bool _isClearingHistory = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rejectedHistoryFuture ??=
        context.read<AppState>().rejectedDriverApplications();
  }

  @override
  void dispose() {
    _rejectedSearchCtrl.dispose();
    super.dispose();
  }

  void _refreshApplicationLists() {
    final rejectedHistory =
        context.read<AppState>().rejectedDriverApplications();
    setState(() {
      _refreshGen++;
      _rejectedHistoryFuture = rejectedHistory;
    });
  }

  String _todaAffiliationLabel(DriverProfile profile) {
    final name = profile.todaName?.trim();
    return name == null || name.isEmpty ? 'Selected TODA unavailable' : name;
  }

  String _municipalityTodaLabel(DriverProfile profile) {
    final municipality = profile.municipality.trim();
    if (profile.vehicleType != VehicleType.tricycle) return municipality;

    final name = profile.todaName?.trim();
    final affiliation =
        name == null || name.isEmpty ? 'TODA unavailable' : name;
    return municipality.isEmpty ? affiliation : '$municipality ($affiliation)';
  }

  List<DriverApplication> _filterAndSortRejected(List<DriverApplication> list) {
    final query = _rejectedSearchCtrl.text.trim().toLowerCase();
    var filtered = list.where((app) {
      if (query.isEmpty) return true;
      final name = app.user.fullName.toLowerCase();
      final email = (app.user.email ?? '').toLowerCase();
      final mobile = app.user.mobile.toLowerCase();
      final refId = (app.applicationId ?? app.user.id).toLowerCase();
      final plate = app.profile.plateNumber.toLowerCase();
      return name.contains(query) ||
          email.contains(query) ||
          mobile.contains(query) ||
          refId.contains(query) ||
          plate.contains(query);
    }).toList();

    filtered.sort((a, b) {
      final aDate = a.reviewedAt ?? a.profile.submittedAt;
      final bDate = b.reviewedAt ?? b.profile.submittedAt;
      return _rejectedSortOrder == 'newest'
          ? bDate.compareTo(aDate)
          : aDate.compareTo(bDate);
    });

    return filtered;
  }

  Widget _buildRejectedControls(List<DriverApplication> allApplications) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AdminTheme.borderLight)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: isMobile ? double.infinity : 280,
            child: TextField(
              controller: _rejectedSearchCtrl,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: AdminTheme.textPrimary, fontSize: 13),
              decoration: AdminTheme.inputDecoration(
                hintText: 'Search by name, email, ref ID...',
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AdminTheme.slate, size: 18),
                suffixIcon: _rejectedSearchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded,
                            size: 16, color: AdminTheme.slate),
                        onPressed: () {
                          _rejectedSearchCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AdminTheme.bgInput,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AdminTheme.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _rejectedSortOrder,
                    dropdownColor: AdminTheme.bgCard,
                    icon: const Icon(Icons.arrow_drop_down, color: AdminTheme.slate),
                    style: const TextStyle(color: AdminTheme.textPrimary, fontSize: 12),
                    items: const [
                      DropdownMenuItem(
                        value: 'newest',
                        child: Text('Newest rejected'),
                      ),
                      DropdownMenuItem(
                        value: 'oldest',
                        child: Text('Oldest rejected'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _rejectedSortOrder = val);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (allApplications.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: _isClearingHistory
                      ? null
                      : () => _confirmClearAllRejected(allApplications.length),
                  icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                  label: const Text('Clear All History'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AdminTheme.dangerText,
                    side: const BorderSide(color: AdminTheme.danger),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearIndividualRejected(DriverApplication application) async {
    final appId = application.applicationId ?? application.user.id;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AdminTheme.border),
        ),
        title: const Text(
          'Clear Rejected Application?',
          style: TextStyle(
            color: AdminTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Remove this application from Rejected History? This will not affect pending applications, approved Drivers, or existing ride records.',
          style: TextStyle(color: AdminTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AdminTheme.slate)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isClearingHistory = true);
      try {
        final success = await context
            .read<AppState>()
            .clearRejectedDriverApplication(appId);
        if (!mounted) return;
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Application removed from rejected history.')),
          );
          _refreshApplicationLists();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to clear application from history.')),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to clear application: $error')),
          );
        }
      } finally {
        if (mounted) setState(() => _isClearingHistory = false);
      }
    }
  }

  Future<void> _confirmClearAllRejected(int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AdminTheme.border),
        ),
        title: const Text(
          'Clear All Rejected History?',
          style: TextStyle(
            color: AdminTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Remove all $count rejected applications from history? This will not affect pending applications, approved Drivers, or existing ride records.',
          style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AdminTheme.slate)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isClearingHistory = true);
      try {
        final clearedCount = await context
            .read<AppState>()
            .clearAllRejectedDriverApplications();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cleared $clearedCount rejected applications from history.')),
        );
        _refreshApplicationLists();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to clear history: $error')),
          );
        }
      } finally {
        if (mounted) setState(() => _isClearingHistory = false);
      }
    }
  }

  Future<void> _showRejectedDetailsDialog(DriverApplication application) async {
    final driver = application.user;
    final profile = application.profile;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth * 0.94).clamp(280.0, 640.0);
    final reviewedAt = application.reviewedAt ?? profile.submittedAt;
    final reviewer =
        application.reviewerName ?? application.reviewedBy ?? 'Admin';
    final reason = driver.rejectionReason?.trim();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
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
              child: const Icon(Icons.cancel_outlined,
                  color: AdminTheme.dangerText, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rejected Driver: ${driver.fullName}',
                    style: const TextStyle(
                      color: AdminTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Rejected ${DateFormat('MMMM d, yyyy h:mm a').format(reviewedAt)}',
                    style: const TextStyle(
                        color: AdminTheme.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const AdminStatusBadge(status: 'rejected'),
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

                _buildSectionHeader('Rejection Information'),
                _buildReviewRow('Status', 'REJECTED'),
                _buildReviewRow('Rejection Date',
                    DateFormat('MMMM d, yyyy h:mm a').format(reviewedAt)),
                _buildReviewRow('Reviewing Admin', reviewer),
                _buildReviewRow(
                    'Rejection Reason',
                    reason == null || reason.isEmpty
                        ? 'No reason recorded'
                        : reason),
                if (application.applicationId != null)
                  _buildReviewRow('Application Ref', application.applicationId!),

                const SizedBox(height: 16),
                _buildSectionHeader('1. Driver Profile & Contact'),
                _buildReviewRow('Full Name', driver.fullName),
                _buildReviewRow('Mobile Number', driver.mobile),
                _buildReviewRow(
                    'Email',
                    (driver.email != null && driver.email!.isNotEmpty)
                        ? driver.email!
                        : '—'),
                _buildReviewRow('Location',
                    '${profile.barangay}, ${profile.municipality}, ${profile.province}'),
                _buildReviewRow('Submitted',
                    DateFormat('MMMM d, yyyy').format(profile.submittedAt)),

                const SizedBox(height: 16),
                _buildSectionHeader('2. Vehicle Information'),
                _buildReviewRow(
                    'Vehicle Type', profile.vehicleType.key.toUpperCase()),
                _buildReviewRow('Plate Number', profile.plateNumber),
                _buildReviewRow(
                    'Make & Model', '${profile.make} ${profile.model}'),
                if (profile.vehicleType == VehicleType.tricycle)
                  _buildReviewRow(
                    'TODA Association',
                    _todaAffiliationLabel(profile),
                  ),

                const SizedBox(height: 16),
                _buildSectionHeader('3. LTO Driver\'s License'),
                _buildReviewRow(
                  'License Status',
                  profile.licenseType?.trim().isNotEmpty == true ||
                          profile.licenseNumber.trim().isNotEmpty ||
                          profile.licenseExpiry.trim().isNotEmpty ||
                          profile.docLicenseFront?.trim().isNotEmpty == true ||
                          profile.docLicenseBack?.trim().isNotEmpty == true
                      ? 'Submitted'
                      : 'No License Submitted',
                ),
                _buildReviewRow(
                    'License Type', profile.licenseType ?? 'Not Provided'),
                _buildReviewRow(
                    'License Number',
                    profile.licenseNumber.trim().isEmpty
                        ? 'Not Provided'
                        : profile.licenseNumber),
                _buildReviewRow(
                    'License Expiry',
                    profile.licenseExpiry.trim().isEmpty
                        ? 'Not Provided'
                        : profile.licenseExpiry),
                _buildReviewRow(
                    'DL Codes',
                    profile.dlCodes.isEmpty
                        ? 'Not Provided'
                        : profile.dlCodes.join(', ')),

                const SizedBox(height: 18),
                _buildSectionHeader(
                    '4. Uploaded Requirements (Supabase Storage)'),
                const SizedBox(height: 8),

                _buildDocumentPreviewCard(
                    'Driver\'s License (Front)', profile.docLicenseFront),
                const SizedBox(height: 8),
                _buildDocumentPreviewCard(
                    'Driver\'s License (Back)', profile.docLicenseBack),
                const SizedBox(height: 8),
                _buildDocumentPreviewCard(
                    'Vehicle OR / CR (Registration)', profile.docOrCr),
                const SizedBox(height: 8),
                _buildDocumentPreviewCard(
                    '2x2 Profile Photo / ID', profile.docProfile),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child:
                const Text('Close', style: TextStyle(color: AdminTheme.slate)),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectedHistory() {
    return FutureBuilder<List<DriverApplication>>(
      future: _rejectedHistoryFuture,
      builder: (context, snapshot) {
        final applications = snapshot.data ?? const <DriverApplication>[];
        final filteredApplications = _filterAndSortRejected(applications);

        return Container(
          decoration: AdminTheme.cardDecoration(),
          child: ExpansionTile(
            leading: const Icon(Icons.history_rounded, color: AdminTheme.slate),
            title: const Text(
              'Rejected Application History',
              style: TextStyle(
                color: AdminTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${applications.length}',
                    style: const TextStyle(color: AdminTheme.textMuted)),
                const Icon(Icons.expand_more_rounded,
                    color: AdminTheme.textMuted),
              ],
            ),
            children: [
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child:
                      CircularProgressIndicator(color: AdminTheme.terracotta),
                )
              else if (snapshot.hasError)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Unable to load rejected applications: ${snapshot.error}',
                    style: const TextStyle(color: AdminTheme.dangerText),
                  ),
                )
              else if (applications.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('No rejected applications yet.',
                      style: TextStyle(color: AdminTheme.textMuted)),
                )
              else ...[
                _buildRejectedControls(applications),
                if (filteredApplications.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('No rejected applications match your search.',
                        style: TextStyle(color: AdminTheme.textMuted)),
                  )
                else
                  ...filteredApplications.map((application) {
                    final reason = application.user.rejectionReason?.trim();
                    final reviewedAt =
                        application.reviewedAt ?? application.profile.submittedAt;
                    final reviewer = application.reviewerName ??
                        application.reviewedBy ??
                        'Admin';

                    return Container(
                      margin:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AdminTheme.bgInput.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AdminTheme.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor:
                                    AdminTheme.danger.withValues(alpha: 0.15),
                                radius: 16,
                                child: Text(
                                  application.user.fullName.isNotEmpty
                                      ? application.user.fullName[0].toUpperCase()
                                      : 'D',
                                  style: const TextStyle(
                                    color: AdminTheme.dangerText,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          application.user.fullName,
                                          style: const TextStyle(
                                            color: AdminTheme.textPrimary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const AdminStatusBadge(status: 'rejected'),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AdminTheme.bgCard,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            border: Border.all(
                                                color: AdminTheme.border),
                                          ),
                                          child: Text(
                                            application.profile.vehicleType.key
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              color: AdminTheme.gold,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 2,
                                      children: [
                                        if (application.user.email != null &&
                                            application.user.email!.isNotEmpty)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.email_outlined,
                                                  size: 13,
                                                  color: AdminTheme.textMuted),
                                              const SizedBox(width: 4),
                                              Text(
                                                application.user.email!,
                                                style: const TextStyle(
                                                    color:
                                                        AdminTheme.textSecondary,
                                                    fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.phone_outlined,
                                                size: 13,
                                                color: AdminTheme.textMuted),
                                            const SizedBox(width: 4),
                                            Text(
                                              application.user.mobile,
                                              style: const TextStyle(
                                                  color:
                                                      AdminTheme.textSecondary,
                                                  fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 16,
                            runSpacing: 4,
                            children: [
                              Text(
                                'Submitted: ${DateFormat('MMM d, yyyy').format(application.profile.submittedAt)}',
                                style: const TextStyle(
                                    color: AdminTheme.textMuted, fontSize: 11),
                              ),
                              Text(
                                'Rejected: ${DateFormat('MMM d, yyyy').format(reviewedAt)}',
                                style: const TextStyle(
                                    color: AdminTheme.dangerText,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'Reviewer: $reviewer',
                                style: const TextStyle(
                                    color: AdminTheme.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                          if (reason != null && reason.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AdminTheme.danger.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Reason: $reason',
                                style: const TextStyle(
                                  color: AdminTheme.dangerText,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _showRejectedDetailsDialog(application),
                                icon: const Icon(Icons.visibility_outlined,
                                    size: 14),
                                label: const Text('View Details'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AdminTheme.slate,
                                  side: const BorderSide(
                                      color: AdminTheme.border),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  textStyle: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: _isClearingHistory
                                    ? null
                                    : () =>
                                        _confirmClearIndividualRejected(application),
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 14),
                                label: const Text('Clear'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AdminTheme.dangerText,
                                  side: const BorderSide(
                                      color: AdminTheme.danger),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  textStyle: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _reviewDriverApplication(
    AppUser driver,
    DriverProfile lightweightProfile, {
    String? applicationId,
    String? applicationStatus,
    String? notificationStatus,
  }) async {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(
            child: CircularProgressIndicator(color: AdminTheme.terracotta)));
    final profile = applicationId == null
        ? await context.read<AppState>().auth.getDriverProfile(driver.id)
        : lightweightProfile;
    Navigator.of(context).pop();
    if (profile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Unable to load this driver application.')),
        );
      }
      return;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth * 0.94).clamp(280.0, 640.0);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
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
                color: AdminTheme.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.how_to_reg_rounded,
                  color: AdminTheme.gold, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Review Driver: ${driver.fullName}',
                    style: const TextStyle(
                      color: AdminTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Submitted ${DateFormat('MMMM d, yyyy').format(profile.submittedAt)}',
                    style: const TextStyle(
                        color: AdminTheme.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            AdminStatusBadge(status: driver.status),
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

                // Personal & Contact
                _buildSectionHeader('1. Driver Profile & Contact'),
                _buildReviewRow('Full Name', driver.fullName),
                _buildReviewRow('Mobile Number', driver.mobile),
                _buildReviewRow(
                    'Email',
                    (driver.email != null && driver.email!.isNotEmpty)
                        ? driver.email!
                        : '—'),
                _buildReviewRow('Location',
                    '${profile.barangay}, ${profile.municipality}, ${profile.province}'),

                const SizedBox(height: 16),
                // Vehicle & TODA
                _buildSectionHeader('2. Vehicle Information'),
                _buildReviewRow(
                    'Vehicle Type', profile.vehicleType.key.toUpperCase()),
                _buildReviewRow('Plate Number', profile.plateNumber),
                _buildReviewRow(
                    'Make & Model', '${profile.make} ${profile.model}'),
                if (profile.vehicleType == VehicleType.tricycle)
                  _buildReviewRow(
                    'TODA Association',
                    _todaAffiliationLabel(profile),
                  ),

                const SizedBox(height: 16),
                // LTO License
                _buildSectionHeader('3. LTO Driver\'s License'),
                _buildReviewRow(
                  'License Status',
                  profile.licenseType?.trim().isNotEmpty == true ||
                          profile.licenseNumber.trim().isNotEmpty ||
                          profile.licenseExpiry.trim().isNotEmpty ||
                          profile.docLicenseFront?.trim().isNotEmpty == true ||
                          profile.docLicenseBack?.trim().isNotEmpty == true
                      ? 'Submitted — not verified'
                      : 'No License Submitted',
                ),
                _buildReviewRow(
                    'License Type', profile.licenseType ?? 'Not Provided'),
                _buildReviewRow(
                    'License Number',
                    profile.licenseNumber.trim().isEmpty
                        ? 'Not Provided'
                        : profile.licenseNumber),
                _buildReviewRow(
                    'License Expiry',
                    profile.licenseExpiry.trim().isEmpty
                        ? 'Not Provided'
                        : profile.licenseExpiry),
                _buildReviewRow(
                    'DL Codes',
                    profile.dlCodes.isEmpty
                        ? 'Not Provided'
                        : profile.dlCodes.join(', ')),

                const SizedBox(height: 18),
                // Uploaded Documents Section
                _buildSectionHeader(
                    '4. Uploaded Requirements (Supabase Storage)'),
                const SizedBox(height: 8),

                _buildDocumentPreviewCard(
                    'Driver\'s License (Front)', profile.docLicenseFront),
                const SizedBox(height: 8),
                _buildDocumentPreviewCard(
                    'Driver\'s License (Back)', profile.docLicenseBack),
                const SizedBox(height: 8),
                _buildDocumentPreviewCard(
                    'Vehicle OR / CR (Registration)', profile.docOrCr),
                const SizedBox(height: 8),
                _buildDocumentPreviewCard(
                    '2x2 Profile Photo / ID', profile.docProfile),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child:
                const Text('Close', style: TextStyle(color: AdminTheme.slate)),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showRejectDialog(
                driver,
                profile.userId,
                applicationId: applicationId,
              );
            },
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Reject Application'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminTheme.dangerText,
              side: const BorderSide(color: AdminTheme.danger),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _showApproveConfirmation(
                driver,
                profile.userId,
                applicationId: applicationId,
                applicationStatus: applicationStatus,
                notificationStatus: notificationStatus,
              );
            },
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text('Approve Driver'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AdminTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style:
                    const TextStyle(color: AdminTheme.textMuted, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: AdminTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentPreviewCard(String label, String? url) {
    final hasUrl = url != null && url.trim().isNotEmpty;
    final isNetwork =
        hasUrl && (url.startsWith('http://') || url.startsWith('https://'));

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AdminTheme.bgInput,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AdminTheme.navyLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.description_outlined,
                color: AdminTheme.gold, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AdminTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  hasUrl ? url : 'Document not uploaded by driver',
                  style: TextStyle(
                    color:
                        hasUrl ? AdminTheme.textMuted : AdminTheme.dangerText,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isNetwork) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.open_in_new_rounded,
                  size: 18, color: AdminTheme.infoText),
              tooltip: 'Open in new tab',
              onPressed: () async {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
            const SizedBox(width: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: GestureDetector(
                onTap: () => _openImageZoomDialog(label, url),
                child: Image.network(
                  url,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 44,
                    height: 44,
                    color: AdminTheme.navyLight,
                    child: const Icon(Icons.broken_image_rounded,
                        size: 20, color: AdminTheme.slate),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openImageZoomDialog(String title, String imageUrl) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AdminTheme.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AdminTheme.border)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: AdminTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AdminTheme.slate),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                          child: CircularProgressIndicator(
                              color: AdminTheme.terracotta));
                    },
                    errorBuilder: (_, __, ___) => const Center(
                      child: Text(
                          'Unable to load document image from Supabase Storage.',
                          style: TextStyle(color: AdminTheme.dangerText)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showApproveConfirmation(
    AppUser driver,
    String applicationUserId, {
    String? applicationId,
    String? applicationStatus,
    String? notificationStatus,
  }) async {
    final isProvisioningRetry = applicationStatus == 'provisioning_failed';
    final isEmailRetry = applicationStatus == 'awaiting_activation' &&
        notificationStatus != 'sent';
    final confirmed = await showAdminConfirmDialog(
      context: context,
      title: isEmailRetry
          ? 'Retry Activation Email'
          : isProvisioningRetry
              ? 'Retry Driver Approval'
              : 'Approve Driver Registration',
      message: isEmailRetry
          ? 'The account is already approved, but its activation email was not sent. Retry sending the secure password-setup link?'
          : isProvisioningRetry
              ? 'The previous account setup did not finish. Retry safely? Existing account records will be reused when they belong to this application.'
              : applicationId == null
                  ? 'Are you sure you want to approve ${driver.fullName}?'
                  : 'Are you sure you want to approve ${driver.fullName}? A secure account invitation will be sent. The driver stays offline until activation.',
      confirmText: isEmailRetry
          ? 'Retry Email'
          : isProvisioningRetry
              ? 'Retry Approval'
              : 'Approve Driver',
      confirmColor: AdminTheme.green,
      icon: Icons.check_circle_rounded,
    );

    if (confirmed == true && mounted) {
      Map<String, dynamic>? result;
      try {
        if (applicationId == null) {
          await context.read<AppState>().approveDriver(applicationUserId);
        } else {
          result =
              await context.read<AppState>().reviewUnlinkedDriverApplication(
                    applicationId: applicationId,
                    decision: 'approve',
                  );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: AdminTheme.danger,
            content: Text('Approval failed: $error'),
          ));
          _refreshApplicationLists();
        }
        return;
      }
      if (mounted) {
        final status = result?['status']?.toString();
        final activationEmailSent = result?['activationEmailSent'] == true;
        final resultNotificationStatus =
            result?['notificationStatus']?.toString();
        final isSuccess = applicationId == null ||
            status == 'active' ||
            status == 'approved' ||
            activationEmailSent;
        final message = isSuccess
            ? 'Driver approved successfully!'
            : 'Approval is saved, but the activation email was not sent (${resultNotificationStatus ?? 'unknown'}). Check the server email configuration, then retry from this queue.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: isSuccess ? AdminTheme.green : AdminTheme.danger,
            content: Text(message),
          ),
        );
        _refreshApplicationLists();
      }
    }
  }

  Future<void> _showRejectDialog(
    AppUser driver,
    String applicationUserId, {
    String? applicationId,
  }) async {
    final reasonCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        var isSubmitting = false;
        String? errorText;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: AdminTheme.bgCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AdminTheme.border),
            ),
            title: Text('Reject Application: ${driver.fullName}',
                style: const TextStyle(
                    color: AdminTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Please specify the exact reason for rejecting this driver application. The decision will be saved before this dialog closes.',
                    style: TextStyle(
                        color: AdminTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 3,
                    style: const TextStyle(
                        color: AdminTheme.textPrimary, fontSize: 13),
                    decoration: AdminTheme.inputDecoration(
                      hintText:
                          'e.g. Expired LTO Driver\'s License, unclear OR/CR photo, plate number mismatch...',
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(errorText!,
                        style: const TextStyle(
                            color: AdminTheme.dangerText, fontSize: 12)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel',
                    style: TextStyle(color: AdminTheme.slate)),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final reason = reasonCtrl.text.trim();
                        if (reason.isEmpty) {
                          setDialogState(() =>
                              errorText = 'Please enter a rejection reason.');
                          return;
                        }
                        setDialogState(() {
                          isSubmitting = true;
                          errorText = null;
                        });
                        try {
                          if (applicationId == null) {
                            await context
                                .read<AppState>()
                                .rejectDriver(applicationUserId, reason);
                          } else {
                            final result = await context
                                .read<AppState>()
                                .reviewUnlinkedDriverApplication(
                                  applicationId: applicationId,
                                  decision: 'reject',
                                  reason: reason,
                                );
                            if (result['status'] != 'rejected') {
                              throw StateError(
                                  'Supabase did not confirm the rejection status.');
                            }
                          }
                          if (!ctx.mounted) return;
                          Navigator.of(ctx).pop();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Driver application rejected and saved.')),
                            );
                            _refreshApplicationLists();
                          }
                        } catch (error) {
                          if (ctx.mounted) {
                            setDialogState(() {
                              isSubmitting = false;
                              errorText = 'Rejection failed: $error';
                            });
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.danger,
                    foregroundColor: Colors.white),
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Confirm Rejection'),
              ),
            ],
          ),
        );
      },
    );
    reasonCtrl.dispose();
  }

  Widget _buildMobileVerificationCard(
      BuildContext context, DriverApplication appItem) {
    final p = appItem.profile;
    final u = appItem.user;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AdminTheme.cardDecoration(),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _reviewDriverApplication(
            u,
            p,
            applicationId: appItem.applicationId,
            applicationStatus: appItem.verificationStatus,
            notificationStatus: appItem.notificationStatus,
          ),
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
                        CircleAvatar(
                          backgroundColor: AdminTheme.navyLight,
                          radius: 18,
                          child: Text(
                            u.fullName.isNotEmpty
                                ? u.fullName[0].toUpperCase()
                                : 'D',
                            style: const TextStyle(
                                color: AdminTheme.gold,
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u.fullName,
                                style: const TextStyle(
                                    color: AdminTheme.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            Text(u.mobile,
                                style: const TextStyle(
                                    color: AdminTheme.textSecondary,
                                    fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AdminTheme.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        p.vehicleType.key.toUpperCase(),
                        style: const TextStyle(
                            color: AdminTheme.gold,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Plate: ${p.plateNumber}',
                        style: const TextStyle(
                            color: AdminTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    Text(_municipalityTodaLabel(p),
                        style: const TextStyle(
                            color: AdminTheme.textMuted, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(color: AdminTheme.borderLight, height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Submitted: ${DateFormat('MMM d, yyyy').format(p.submittedAt)}',
                      style: const TextStyle(
                          color: AdminTheme.textMuted, fontSize: 11),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _reviewDriverApplication(
                        u,
                        p,
                        applicationId: appItem.applicationId,
                        applicationStatus: appItem.verificationStatus,
                        notificationStatus: appItem.notificationStatus,
                      ),
                      icon: const Icon(Icons.rate_review_rounded, size: 14),
                      label: const Text('Review Docs'),
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
                  ],
                ),
              ],
            ),
          ),
        ),
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
        AdminSectionHeader(
          title: 'Verify Driver Registration',
          subtitle:
              'Review driver identification documents, inspect vehicle registration, and approve or reject applications.',
        ),

        // ── Driver Verification Queue ────────────────────────
        AdminDataStreamBuilder<List<DriverApplication>>(
          section: 'driver_verification',
          key: ValueKey('driver_verification_$_refreshGen'),
          streamFactory: () => app.pendingDriverApplicationsStream(),
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

            final applications = snapshot.data ?? [];
            if (applications.isEmpty) {
              return Container(
                decoration: AdminTheme.cardDecoration(),
                padding: const EdgeInsets.all(48),
                child: const AdminEmptyState(
                  icon: Icons.verified_user_rounded,
                  title: 'No Pending Applications',
                  subtitle:
                      'There are currently no new driver registrations awaiting administrator review.',
                ),
              );
            }

            // Mobile Card View
            if (isMobile) {
              return Column(
                children: applications
                    .map((item) => _buildMobileVerificationCard(context, item))
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
                        label: Text('APPLICANT',
                            style: TextStyle(
                                color: AdminTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('MOBILE',
                            style: TextStyle(
                                color: AdminTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('VEHICLE TYPE',
                            style: TextStyle(
                                color: AdminTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('PLATE NO.',
                            style: TextStyle(
                                color: AdminTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('LICENSE NO.',
                            style: TextStyle(
                                color: AdminTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('MUNICIPALITY / TODA',
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
                        label: Text('ACTIONS',
                            style: TextStyle(
                                color: AdminTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                  ],
                  rows: applications.map((appItem) {
                    final p = appItem.profile;
                    final u = appItem.user;

                    return DataRow(
                      cells: [
                        DataCell(
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AdminTheme.navyLight,
                                radius: 14,
                                child: Text(
                                  u.fullName.isNotEmpty
                                      ? u.fullName[0].toUpperCase()
                                      : 'D',
                                  style: const TextStyle(
                                      color: AdminTheme.gold,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(u.fullName,
                                  style: const TextStyle(
                                      color: AdminTheme.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        DataCell(Text(u.mobile,
                            style: const TextStyle(
                                color: AdminTheme.textSecondary,
                                fontSize: 12))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AdminTheme.bgInput,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(p.vehicleType.key.toUpperCase(),
                                style: const TextStyle(
                                    color: AdminTheme.gold,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                        DataCell(Text(p.plateNumber,
                            style: const TextStyle(
                                color: AdminTheme.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600))),
                        DataCell(Text(
                            p.licenseNumber.trim().isEmpty
                                ? 'Not Provided'
                                : p.licenseNumber,
                            style: const TextStyle(
                                color: AdminTheme.textMuted, fontSize: 12))),
                        DataCell(Text(_municipalityTodaLabel(p),
                            style: const TextStyle(
                                color: AdminTheme.textSecondary,
                                fontSize: 12))),
                        DataCell(Text(
                            DateFormat('MMM d, yyyy').format(p.submittedAt),
                            style: const TextStyle(
                                color: AdminTheme.textMuted, fontSize: 12))),
                        DataCell(
                          ElevatedButton.icon(
                            onPressed: () => _reviewDriverApplication(
                              u,
                              p,
                              applicationId: appItem.applicationId,
                              applicationStatus: appItem.verificationStatus,
                              notificationStatus: appItem.notificationStatus,
                            ),
                            icon:
                                const Icon(Icons.visibility_rounded, size: 14),
                            label: const Text('Review Docs'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AdminTheme.terracotta,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
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
        const SizedBox(height: 18),
        _buildRejectedHistory(),
      ],
    );
  }
}

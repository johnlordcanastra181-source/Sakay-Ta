import 'package:flutter/material.dart';
import '../models/firestore_models.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../main.dart' hide Brand, Avatar;

import '../state/app_state.dart';

class HeadingHome extends StatelessWidget {
  const HeadingHome({super.key, required this.onNavigate});
  final Function(AppScreen) onNavigate;
  @override
  Widget build(BuildContext context) => PageFrame(
        child: Column(
          children: [
            AppTop(
                title: 'Driver Applications',
                back: () => onNavigate(AppScreen.login)),
            Expanded(
              child: StreamBuilder<List<DriverApplication>>(
                stream:
                    context.read<AppState>().pendingDriverApplicationsStream(),
                initialData: const [],
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                        child: Text(
                            'Unable to load pending applications. Please try again.'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final applications = snapshot.data ?? const [];
                  if (applications.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_user_outlined, size: 48),
                          SizedBox(height: 8),
                          Text('No driver applications are pending review.'),
                        ],
                      ),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        '${applications.length} pending application${applications.length == 1 ? '' : 's'}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      ...applications.map((application) => _ApplicationCard(
                          application: application, onNavigate: onNavigate)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.application, required this.onNavigate});
  final DriverApplication application;
  final Function(AppScreen) onNavigate;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    child: Text(
                      application.user.fullName.isEmpty
                          ? '?'
                          : application.user.fullName.substring(0, 1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          application.user.fullName.isEmpty
                              ? 'Unnamed driver'
                              : application.user.fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${application.profile.vehicleType.key} • ${application.profile.plateNumber}',
                        ),
                      ],
                    ),
                  ),
                  const Chip(label: Text('PENDING')),
                ],
              ),
              const SizedBox(height: 8),
              Text('Submitted: ${_date(application.profile.submittedAt)}'),
              if (application.profile.barangay.isNotEmpty ||
                  application.profile.municipality.isNotEmpty)
                Text(
                  'Location: ${[
                    application.profile.barangay,
                    application.profile.municipality,
                    application.profile.province
                  ].where((part) => part.isNotEmpty).join(', ')}',
                ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => _review(context),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Review'),
                ),
              ),
            ],
          ),
        ),
      );

  Future<void> _review(BuildContext context) async {
    final profile = application.profile;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                application.user.fullName,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _line('Mobile', application.user.mobile),
              _line('License', profile.licenseNumber),
              _line(
                'Vehicle',
                '${profile.make} ${profile.model} • ${profile.plateNumber}',
              ),
              _line('Address', profile.address),
              const SizedBox(height: 14),
              const Text(
                'Uploaded documents',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              _document('License front', profile.docLicenseFront),
              _document('License back', profile.docLicenseBack),
              _document('OR/CR', profile.docOrCr),
              _document('Profile photo', profile.docProfile),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _reject(sheetContext),
                      style:
                          OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _approve(sheetContext),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text('$label: ${value.isEmpty ? 'Not provided' : value}'),
      );

  Widget _document(String label, String? url) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.attach_file),
        title: Text(label),
        subtitle: Text(
          url?.isNotEmpty == true ? url! : 'Not uploaded',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      );

  Future<void> _approve(BuildContext context) async {
    try {
      await context.read<AppState>().approveDriver(application.profile.userId);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driver approved and notified.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not approve driver. Please try again.')),
        );
      }
    }
  }

  Future<void> _reject(BuildContext context) async {
    final reason = TextEditingController();
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject application'),
        content: TextField(
          controller: reason,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Reason for rejection'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (reason.text.trim().isEmpty) return;
              Navigator.pop(dialogContext);
              try {
                await context.read<AppState>().rejectDriver(
                      application.profile.userId,
                      reason.text.trim(),
                    );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Driver rejected and notified.')),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Could not reject driver. Please try again.')),
                  );
                }
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  String _date(DateTime value) => '${value.day}/${value.month}/${value.year}';
}

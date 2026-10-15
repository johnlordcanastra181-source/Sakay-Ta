import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('Rejected Driver Application History & Clear History Contracts', () {
    test('migration introduces soft-clear columns and security-definer RPCs', () {
      final migration = _read(
        'supabase/migrations/202610140001_clear_rejected_driver_application_history.sql',
      );
      expect(migration, contains('add column if not exists history_cleared_at timestamptz'));
      expect(migration, contains('add column if not exists history_cleared_by uuid references public.profiles(id)'));
      expect(migration, contains('public.driver_applications'));
      expect(migration, contains('public.drivers'));
      expect(migration, contains('create or replace function public.clear_rejected_driver_application'));
      expect(migration, contains('create or replace function public.clear_all_rejected_driver_applications'));
      expect(migration, contains('if not public.is_admin() then'));
      expect(migration, contains("and status = 'rejected'"));
      expect(migration, contains("and application_status = 'rejected'"));
      expect(migration, contains('history_cleared_at is null'));
      expect(migration, contains('security definer'));
    });

    test('edge function excludes cleared rejected records and returns reviewer info', () {
      final edge = _read('supabase/functions/driver-applications/index.ts');
      expect(edge, contains(".is('history_cleared_at', null)"));
      expect(edge, contains('reviewer_name:'));
      expect(edge, contains('reviewed_by:'));
      expect(edge, contains("case 'clear_rejected':"));
      expect(edge, contains("case 'clear_all_rejected':"));
      expect(edge, contains('clear_rejected_driver_application'));
      expect(edge, contains('clear_all_rejected_driver_applications'));
    });

    test('database service filters cleared history and exposes clear RPCs', () {
      final dbService = _read('lib/services/supabase_database_service.dart');
      expect(dbService, contains(".isFilter('history_cleared_at', null)"));
      expect(dbService, contains('clearRejectedDriverApplication'));
      expect(dbService, contains('clearAllRejectedDriverApplications'));
      expect(dbService, contains("'clear_rejected_driver_application'"));
      expect(dbService, contains("'clear_all_rejected_driver_applications'"));
      expect(dbService, contains('reviewerName'));
      expect(dbService, contains('reviewedBy'));
    });

    test('driver verification view has search, sort, view details, and clear actions', () {
      final view = _read('lib/pages/admin/views/driver_verification_view.dart');
      expect(view, contains('_rejectedSearchCtrl'));
      expect(view, contains('_rejectedSortOrder'));
      expect(view, contains('_filterAndSortRejected'));
      expect(view, contains('Clear All History'));
      expect(view, contains('Clear Rejected Application?'));
      expect(view, contains('Clear All Rejected History?'));
      expect(view, contains('Remove this application from Rejected History?'));
      expect(view, contains('_showRejectedDetailsDialog'));
      expect(view, contains('_confirmClearIndividualRejected'));
      expect(view, contains('_confirmClearAllRejected'));
      expect(view, contains('clearRejectedDriverApplication'));
      expect(view, contains('clearAllRejectedDriverApplications'));
      expect(view, contains('TODA Association'));
      expect(view, contains('if (profile.vehicleType == VehicleType.tricycle)'));
    });

    test('firestore models include reviewer tracking fields', () {
      final models = _read('lib/models/firestore_models.dart');
      expect(models, contains('final String? reviewedBy;'));
      expect(models, contains('final String? reviewerName;'));
    });
  });
}


import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:sakay_ta/models/report_model.dart';

void main() {
  group('Report submission contract', () {
    test('admin placeholder ids are not valid UUIDs (would hit 22P02)', () {
      expect(Uuid.isValidUUID(fromString: 'admin_manual'), isFalse);
      expect(Uuid.isValidUUID(fromString: 'Juan Driver'), isFalse);
      expect(Uuid.isValidUUID(fromString: const Uuid().v4()), isTrue);
    });

    test('new report defaults satisfy reports_authenticated_create', () {
      final uid = const Uuid().v4();
      final report = FireReport(
        id: 'rep_1',
        reporterId: uid,
        reporterName: 'Passenger',
        type: ReportType.lostItem,
        title: 'Lost wallet',
        description: 'Left in tricycle',
        createdAt: DateTime.utc(2026, 10, 15),
      );
      expect(report.status, ReportStatus.pending);
      expect(report.reporterId, uid);
      expect(report.updatedAt, isNull);
    });

    test('fromMap round-trips snake_case Supabase rows', () {
      final uid = const Uuid().v4();
      final row = {
        'id': 'rep_2',
        'reporter_id': uid,
        'reporter_name': 'Ana',
        'reporter_role': 'passenger',
        'ride_id': 'ride_9',
        'type': ReportType.overcharging,
        'title': 'Overcharged',
        'description': 'Fare too high',
        'status': 'pending',
        'priority': 'normal',
        'admin_notes': <String>[],
        'created_at': '2026-10-15T10:00:00Z',
      };
      final r = FireReport.fromMap(row, row['id'] as String);
      expect(r.reporterId, uid);
      expect(r.rideId, 'ride_9');
      expect(r.type, ReportType.overcharging);
      expect(r.status, ReportStatus.pending);
    });

    test('fromMap tolerates null reporter (admin-filed / deleted account)', () {
      final r = FireReport.fromMap({
        'id': 'rep_3',
        'reporter_id': null,
        'reporter_name': null,
        'type': 'safety',
        'title': 'x',
        'description': 'y',
      });
      expect(r.reporterId, '');
      expect(r.reporterName, 'Unknown');
    });

    test('ReportType.isRideRelated accurately separates ride from general issues', () {
      expect(ReportType.isRideRelated(ReportType.safety), isTrue);
      expect(ReportType.isRideRelated(ReportType.overcharging), isTrue);
      expect(ReportType.isRideRelated(ReportType.lostItem), isTrue);
      expect(ReportType.isRideRelated(ReportType.driverBehavior), isTrue);
      expect(ReportType.isRideRelated(ReportType.passengerBehavior), isTrue);
      expect(ReportType.isRideRelated(ReportType.vehicleCondition), isTrue);

      expect(ReportType.isRideRelated(ReportType.appBug), isFalse);
      expect(ReportType.isRideRelated(ReportType.other), isFalse);
      expect(ReportType.isRideRelated('general_ticket'), isFalse);
    });

    test('General report allows rideId = null without breaking schema', () {
      final uid = const Uuid().v4();
      final generalReport = FireReport(
        id: 'rep_general_1',
        reporterId: uid,
        reporterName: 'Carlos',
        reporterRole: 'passenger',
        rideId: null,
        type: ReportType.appBug,
        title: 'Map not loading',
        description: 'Unable to select pickup pin',
        createdAt: DateTime.utc(2026, 10, 15, 12, 0),
      );

      final map = generalReport.toMap();
      expect(map['rideId'], isNull);
      expect(map['ride_id'], isNull);
      expect(map['type'], ReportType.appBug);
      expect(map['status'], ReportStatus.pending);
    });

    test('Ride-related report retains valid rideId', () {
      final uid = const Uuid().v4();
      const validRideId = 'bd8c555b-db8d-4b3e-a1ac-39581bfe3bb4';
      final rideReport = FireReport(
        id: 'rep_ride_1',
        reporterId: uid,
        reporterName: 'Maria',
        reporterRole: 'passenger',
        rideId: validRideId,
        type: ReportType.overcharging,
        title: 'Extra charge requested',
        description: 'Driver charged PHP 50 extra',
        createdAt: DateTime.utc(2026, 10, 15, 12, 30),
      );

      final map = rideReport.toMap();
      expect(map['rideId'], validRideId);
      expect(map['ride_id'], validRideId);
      expect(map['type'], ReportType.overcharging);
    });

    test('Resolution summary validation contract for resolved status', () {
      bool isResolutionValid(String status, String? summary) {
        if (status == ReportStatus.resolved) {
          return summary != null && summary.trim().isNotEmpty;
        }
        return true;
      }

      expect(isResolutionValid(ReportStatus.resolved, ''), isFalse);
      expect(isResolutionValid(ReportStatus.resolved, '   '), isFalse);
      expect(isResolutionValid(ReportStatus.resolved, null), isFalse);
      expect(
          isResolutionValid(ReportStatus.resolved, 'Passenger was refunded.'),
          isTrue);

      // Non-resolved statuses do not require resolution summary
      expect(isResolutionValid(ReportStatus.pending, ''), isTrue);
      expect(isResolutionValid(ReportStatus.underInvestigation, null), isTrue);
      expect(isResolutionValid(ReportStatus.dismissed, ''), isTrue);
    });

    test('Status transition to resolved retains resolution details and timestamps', () {
      final adminUid = const Uuid().v4();
      final report = FireReport(
        id: 'rep_100',
        reporterId: const Uuid().v4(),
        reporterName: 'Juan',
        type: ReportType.lostItem,
        title: 'Lost phone',
        description: 'Black iPhone in tricycle',
        createdAt: DateTime.utc(2026, 10, 15, 10, 0),
      );

      final now = DateTime.utc(2026, 10, 15, 11, 0);
      final resolvedReport = report.copyWith(
        status: ReportStatus.resolved,
        resolutionSummary: 'Phone returned to passenger at TODA terminal.',
        resolvedByAdminId: adminUid,
        resolvedAt: now,
        updatedAt: now,
      );

      expect(resolvedReport.status, ReportStatus.resolved);
      expect(resolvedReport.resolutionSummary,
          'Phone returned to passenger at TODA terminal.');
      expect(resolvedReport.resolvedByAdminId, adminUid);
      expect(resolvedReport.resolvedAt, now);

      final map = resolvedReport.toMap();
      expect(map['status'], ReportStatus.resolved);
      expect(map['resolution_summary'],
          'Phone returned to passenger at TODA terminal.');
      expect(map['resolved_by'], adminUid);
      expect(map['resolved_at'], isNotNull);
    });

    test('Adding investigation note does not alter existing report status', () {
      final report = FireReport(
        id: 'rep_200',
        reporterId: const Uuid().v4(),
        reporterName: 'Ana',
        type: ReportType.driverBehavior,
        title: 'Rude driver',
        description: 'Driver refused to give change',
        status: ReportStatus.pending,
        adminNotes: const ['First contact attempted via phone'],
        createdAt: DateTime.utc(2026, 10, 15, 8, 0),
      );

      // Appending a note must NOT change status to under_investigation or anything else
      final updatedNotes = List<String>.from(report.adminNotes)
        ..add('Passenger confirmed receipt of change.');

      final updatedReport = report.copyWith(
        adminNotes: updatedNotes,
        updatedAt: DateTime.utc(2026, 10, 15, 9, 30),
      );

      expect(updatedReport.status, ReportStatus.pending);
      expect(updatedReport.adminNotes.length, 2);
      expect(updatedReport.adminNotes.last,
          'Passenger confirmed receipt of change.');
    });
  });
}


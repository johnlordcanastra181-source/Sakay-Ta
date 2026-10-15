import 'package:flutter_test/flutter_test.dart';
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/models/admin_account.dart';
import 'package:sakay_ta/models/app_user.dart';
import 'package:sakay_ta/models/driver_profile.dart';
import 'package:sakay_ta/models/firestore_models.dart';
import 'package:sakay_ta/models/report_model.dart';
import 'package:sakay_ta/services/firestore_service.dart';

void main() {
  group('Flutter Web Admin Dashboard Models & Logic', () {
    test('FireReport model correctly converts to and from Firestore map', () {
      final report = FireReport(
        id: 'rep_123',
        type: ReportType.overcharging,
        title: 'Overcharging dispute on trip',
        description: 'Driver charged beyond the standard TODA fare matrix.',
        status: ReportStatus.pending,
        reporterId: 'passenger_001',
        reporterName: 'Juan Dela Cruz',
        reporterRole: 'passenger',
        reportedUserId: 'driver_002',
        reportedUserName: 'Pedro Driver',
        reportedUserRole: 'driver',
        rideId: 'ride_999',
        createdAt: DateTime(2026, 8, 26, 10, 0),
        adminNotes: [
          'Admin Clara: Contacted passenger for fare receipt confirmation.',
        ],
      );

      final map = report.toMap();
      expect(map['type'], equals('overcharging'));
      expect(map['title'], equals('Overcharging dispute on trip'));
      expect(map['reporterName'], equals('Juan Dela Cruz'));
      expect(map['adminNotes'], isA<List>());
      expect((map['adminNotes'] as List).length, equals(1));

      final fromMap = FireReport.fromMap(map);
      expect(fromMap.id, equals('rep_123'));
      expect(fromMap.status, equals(ReportStatus.pending));
      expect(fromMap.adminNotes.length, equals(1));
      expect(fromMap.adminNotes.first, contains('Admin Clara'));
    });

    test('FireReport copyWith correctly updates status and resolution', () {
      final report = FireReport(
        id: 'rep_456',
        type: ReportType.driverBehavior,
        title: 'Reckless driving report',
        description: 'Driver drove through red light.',
        status: ReportStatus.underInvestigation,
        reporterId: 'p_1',
        reporterName: 'Maria Santos',
        reporterRole: 'passenger',
        createdAt: DateTime.now(),
      );

      final resolved = report.copyWith(
        status: ReportStatus.resolved,
        resolutionSummary: 'Driver warned and issued 3-day suspension.',
      );

      expect(resolved.status, equals(ReportStatus.resolved));
      expect(resolved.resolutionSummary,
          equals('Driver warned and issued 3-day suspension.'));
      expect(resolved.id, equals(report.id));
    });

    test('FirePayment calculations for platform commission and driver net', () {
      final payment = FirePayment(
        id: 'pay_777',
        rideId: 'ride_888',
        payerId: 'p_1',
        payeeId: 'd_1',
        amount: 250.0,
        method: 'gcash',
        status: 'paid',
        reference: 'GCASH-998822',
        createdAt: DateTime.now(),
      );

      final commission = payment.amount * RideConfig.commissionRate;
      final net = payment.amount - commission;

      expect(commission, equals(30.0));
      expect(net, equals(220.0));
      expect(payment.method, equals('gcash'));
      expect(payment.status, equals('paid'));
    });

    test('DriverApplication links user and profile for document review', () {
      final user = AppUser(
        id: 'driver_u1',
        fullName: 'Efren Bata',
        mobile: '09181234567',
        passwordHash: 'hash',
        role: UserRole.driver,
        status: AccountStatus.pending,
        createdAt: DateTime.now(),
      );

      final profile = DriverProfile(
        userId: 'driver_u1',
        vehicleType: VehicleType.tricycle,
        plateNumber: 'CEB-1234',
        licenseNumber: 'N01-12-345678',
        licenseExpiry: '2028-12-31',
        todaName: 'Lahug TODA',
        municipality: 'Cebu City',
        province: 'Cebu',
        docLicenseFront:
            'https://storage.googleapis.com/sakay-ta.appspot.com/drivers/license_front.jpg',
        docLicenseBack:
            'https://storage.googleapis.com/sakay-ta.appspot.com/drivers/license_back.jpg',
        docOrCr:
            'https://storage.googleapis.com/sakay-ta.appspot.com/drivers/or_cr.jpg',
        docProfile:
            'https://storage.googleapis.com/sakay-ta.appspot.com/drivers/profile_pic.jpg',
        submittedAt: DateTime.now(),
      );

      final application = DriverApplication(
        user: user,
        profile: profile,
        verificationStatus: AccountStatus.pending,
      );

      expect(application.user.isDriver, isTrue);
      expect(application.profile.plateNumber, equals('CEB-1234'));
      expect(
          application.profile.docLicenseFront, contains('license_front.jpg'));
      expect(application.profile.docOrCr, contains('or_cr.jpg'));
      expect(application.verificationStatus, equals(AccountStatus.pending));
    });

    test('Driver status keeps approval and suspension distinct', () {
      final approved = AppUser.fromMap({
        'id': 'driver_approved',
        'role': UserRole.driver,
        'status': AccountStatus.pending,
        'verificationStatus': AccountStatus.approved,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      final suspended = AppUser.fromMap({
        'id': 'driver_suspended',
        'role': UserRole.driver,
        'status': AccountStatus.suspended,
        'verificationStatus': AccountStatus.approved,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });

      expect(approved.status, equals(AccountStatus.approved));
      expect(suspended.status, equals(AccountStatus.suspended));
    });

    test('AdminAccount permissions and status verification', () {
      final admin = AdminAccount(
        id: 'adm_1',
        fullName: 'Chief Operations Admin',
        email: 'admin@sakayta.app',
        mobile: '09170001122',
        passwordHash: 'hash',
        role: UserRole.admin,
        status: AccountStatus.active,
        permissions: AdminPermissions.all,
        department: 'Executive Operations',
        createdAt: DateTime.now(),
      );

      expect(admin.role, equals(UserRole.admin));
      expect(admin.isActive, isTrue);
      expect(admin.hasPermission(AdminPermissions.all), isTrue);
      expect(admin.hasPermission('verify_drivers'), isTrue);
    });
  });
}

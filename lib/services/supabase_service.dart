import 'dart:async';
import 'dart:typed_data';

import '../core/constants.dart';
import '../models/admin_account.dart';
import '../models/app_user.dart';
import 'driver_matching_service.dart';
import '../models/driver_profile.dart';
import '../models/firestore_models.dart';
import '../models/report_model.dart';
import '../models/toda.dart';
import '../models/trip.dart';
import '../models/transaction.dart';
import '../models/philippine_address.dart';
import 'driver_earnings_summary.dart';

import 'supabase/admin_service.dart';
import 'supabase/finance_service.dart';
import 'supabase/notification_service.dart';
import 'supabase/rating_service.dart';
import 'supabase/auth_helpers.dart' as auth;

import '../core/supabase_config.dart';
import 'database_service.dart';
import 'supabase_database_service.dart';

class SupabaseService {
  final _adminService = SupabaseAdminService.instance;
  final _financeService = SupabaseFinanceService.instance;
  final _notificationService = SupabaseNotificationService.instance;
  final _ratingService = SupabaseRatingService.instance;
  final _database = SupabaseDatabaseService.instance;

  Stream<List<AppUser>> streamDrivers({String? status}) {
    return _database.streamDrivers(status: status);
  }

  Stream<List<AppUser>> streamPassengers() {
    return _database.streamPassengers();
  }

  Stream<int> streamAdminTotalRides() => _database.streamAdminTotalRides();
  Stream<int> streamAdminActiveRides() => _database.streamAdminActiveRides();
  Stream<int> streamAdminCompletedRides() =>
      _database.streamAdminCompletedRides();
  Stream<int> streamAdminCancelledRides() =>
      _database.streamAdminCancelledRides();

  Future<int> adminTotalDriversOnce() => _database.adminTotalDriversOnce();
  Future<int> adminTotalPassengersOnce() =>
      _database.adminTotalPassengersOnce();
  Future<int> adminActiveDriversOnce() => _database.adminActiveDriversOnce();
  Future<double> adminRevenueTodayOnce() => _database.adminRevenueTodayOnce();

  Future<bool> adminHealthOnce() {
    return _database.adminHealthOnce();
  }

  Future<List<AppUser>> getOnlineDrivers({String? vehicleType}) {
    return _database.getOnlineDrivers(vehicleType: vehicleType);
  }

  Future<void> ensureCurrentAdminAuthorized([String? explicitUid]) {
    return _adminService.ensureCurrentAdminAuthorized(explicitUid);
  }

  Future<bool> isCurrentAdminAuthorized([String? explicitUid]) {
    return _adminService.isCurrentAdminAuthorized(explicitUid);
  }

  Future<List<Map<String, dynamic>>> todasOnce() async {
    return _database.eligibleDriverTodasOnce();
  }

  Future<List<Trip>> getPassengerTrips(String passengerId,
      {int limit = 20, String? status}) {
    return _database.getPassengerTrips(passengerId);
  }

  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();
  static bool get isConfigured => SupabaseConfig.isInitialized;

  Future<void> init() async {}

  Future<void> saveUser(AppUser user) {
    return _database.saveUser(user);
  }

  Future<void> updateUser(String userId, Map<String, Object?> fields) {
    return _database.updateUser(userId, fields);
  }

  Stream<AppUser?> streamUser(String userId) {
    return _database.streamUser(userId);
  }

  Future<AppUser?> getUser(String userId) {
    return _database.getUser(userId);
  }

  Future<AppUser?> getUserByEmail(String email) {
    return _database.getUserByEmail(email);
  }

  Future<AppUser?> getUserByMobile(String mobile) {
    return _database.getUserByMobile(mobile);
  }

  Future<void> deleteUser(String userId) {
    return _database.deleteUser(userId);
  }

  Future<void> saveDriverLocation({
    required String userId,
    required double latitude,
    required double longitude,
  }) {
    return _database.saveDriverLocation(
        userId: userId, latitude: latitude, longitude: longitude);
  }

  Stream<DriverLiveLocation?> streamDriverLocation(String driverId) {
    return _database.streamDriverLocation(driverId);
  }

  Future<void> setDriverAvailability(String userId, bool isOnline) {
    return _database.setDriverAvailability(userId, isOnline);
  }

  Future<String?> startDriverOnlineSession() {
    return _database.startDriverOnlineSession();
  }

  Future<bool> stopDriverOnlineSession() {
    return _database.stopDriverOnlineSession();
  }

  Future<bool> setDriverOffline() {
    return _database.setDriverOffline();
  }

  Future<bool> heartbeatDriverOnlineSession() {
    return _database.heartbeatDriverOnlineSession();
  }

  Future<double> driverOnlineHoursToday(String driverId) {
    return _database.driverOnlineHoursToday(driverId);
  }

  Future<void> saveDriverProfile(DriverProfile profile) {
    return _database.saveDriverProfile(profile);
  }

  Future<void> submitDriverApplication({
    required AppUser user,
    required DriverProfile profile,
  }) {
    return _database.submitDriverApplication(user: user, profile: profile);
  }

  Future<({String applicationId, String statusToken, String status})>
      submitUnlinkedDriverApplication({
    required String fullName,
    required String email,
    required String mobile,
    required DriverProfile profile,
    required String submissionKey,
    required String statusToken,
    required Map<String, Uint8List> documentBytes,
    required Map<String, String> documentContentTypes,
  }) =>
          _database.submitUnlinkedDriverApplication(
            fullName: fullName,
            email: email,
            mobile: mobile,
            profile: profile,
            submissionKey: submissionKey,
            statusToken: statusToken,
            documentBytes: documentBytes,
            documentContentTypes: documentContentTypes,
          );

  Future<Map<String, dynamic>> getUnlinkedDriverApplicationStatus({
    required String applicationId,
    required String statusToken,
  }) =>
      _database.getUnlinkedDriverApplicationStatus(
        applicationId: applicationId,
        statusToken: statusToken,
      );

  Future<List<DriverApplication>> fetchRejectedDriverApplications() =>
      _database.fetchRejectedDriverApplications();

  Future<bool> clearRejectedDriverApplication(String applicationId) =>
      _database.clearRejectedDriverApplication(applicationId);

  Future<int> clearAllRejectedDriverApplications() =>
      _database.clearAllRejectedDriverApplications();

  Future<Map<String, dynamic>> reviewUnlinkedDriverApplication({
    required String applicationId,
    required String decision,
    String? reason,
  }) =>
      _database.reviewUnlinkedDriverApplication(
        applicationId: applicationId,
        decision: decision,
        reason: reason,
      );

  Future<void> activateInvitedDriver() => _database.activateInvitedDriver();

  Future<void> updateDriverProfile(DriverProfile profile) {
    return _database.updateDriverProfile(profile);
  }

  Future<DriverProfile?> getDriverProfile(String userId) {
    return _database.getDriverProfile(userId);
  }

  Future<String?> getDriverVerificationStatus(String userId) {
    return _database.getDriverVerificationStatus(userId);
  }

  Stream<DriverProfile?> streamDriverProfile(String userId) {
    return _database.streamDriverProfile(userId);
  }

  Future<void> setDriverVerificationStatus(
    String userId,
    String status, {
    String? reason,
  }) {
    return _database.setDriverVerificationStatus(userId, status,
        reason: reason);
  }

  Stream<PassengerCloudProfile?> streamPassengerProfile(String userId) {
    return _database.streamPassengerProfile(userId);
  }

  Future<void> savePassengerProfile(
    String userId, {
    List<String>? savedAddresses,
    String? defaultAddress,
    List<String>? paymentMethods,
    PhilippineAddress? address,
    bool initialize = false,
  }) {
    return _database.savePassengerProfile(userId,
        savedAddresses: savedAddresses,
        defaultAddress: defaultAddress,
        paymentMethods: paymentMethods,
        address: address,
        initialize: initialize);
  }

  Future<void> incrementPassengerRideCount(String userId) {
    return _database.incrementPassengerRideCount(userId);
  }

  Future<Trip?> saveTrip(Trip trip) {
    return _database.saveTrip(trip);
  }

  Future<void> updateTrip(String tripId, Map<String, Object?> fields) {
    return _database.updateTrip(tripId, fields);
  }

  Stream<Trip?> streamActiveTripForPassenger(String passengerId) {
    return _database.streamActiveTripForPassenger(passengerId);
  }

  Stream<Trip?> streamActiveTripForDriver(String driverId) {
    return _database.streamActiveTripForDriver(driverId);
  }

  Stream<List<Trip>> streamActiveTripsForDriver(String driverId) {
    return _database.streamActiveTripsForDriver(driverId);
  }

  Future<bool> atomicAcceptBooking({
    required String rideId,
    required AppUser driver,
  }) {
    return _database.atomicAcceptBooking(rideId: rideId, driver: driver);
  }

  Future<bool> transitionDriverRide({
    required String rideId,
    required String driverId,
    required Set<String> fromStatuses,
    required String toStatus,
  }) {
    return _database.transitionDriverRide(
        rideId: rideId,
        driverId: driverId,
        fromStatuses: fromStatuses,
        toStatus: toStatus);
  }

  Future<bool> cancelRide({required String rideId}) {
    return _database.cancelRide(rideId: rideId);
  }

  Future<void> declineBooking({
    required String rideId,
    required String driverId,
  }) {
    return _database.declineBooking(rideId: rideId, driverId: driverId);
  }

  Stream<Trip?> streamTrip(String rideId) {
    return _database.streamTrip(rideId);
  }

  Future<Trip?> getTrip(String tripId) {
    return _database.getTrip(tripId);
  }

  Future<bool> isDriverBookable(String driverId) {
    return _database.isDriverBookable(driverId);
  }

  Future<bool> isDriverRequestable(String driverId) {
    return _database.isDriverRequestable(driverId);
  }

  Future<void> saveBooking(Map<String, dynamic> bookingMap) {
    return _database.saveBooking(bookingMap);
  }

  Future<void> saveChatMessage(ChatMessage message) {
    return _database.saveChatMessage(message);
  }

  Future<void> saveRating(FireRating rating) {
    return _ratingService.saveRating(rating);
  }

  Future<void> savePayment(FirePayment payment) {
    return _financeService.savePayment(payment);
  }

  Future<FirePayment?> getPayment(String paymentId) {
    return _financeService.getPayment(paymentId);
  }

  Future<FirePayment?> getPaymentForRide(String rideId) {
    return _financeService.getPaymentForRide(rideId);
  }

  Stream<FirePayment?> streamPayment(String paymentId) {
    return _database.streamPayment(paymentId);
  }

  Stream<FirePayment?> streamPaymentForRide(String rideId) {
    return _database.streamPaymentForRide(rideId);
  }

  Future<bool> atomicSettleRidePayment({
    required String paymentId,
    required String rideId,
    required String driverId,
    required String passengerId,
    required double fare,
    required double commission,
    required double net,
    required String method,
    required String reference,
    String? gatewayPaymentId,
  }) {
    return _financeService.atomicSettleRidePayment(
        paymentId: paymentId,
        rideId: rideId,
        driverId: driverId,
        passengerId: passengerId,
        fare: fare,
        commission: commission,
        net: net,
        method: method,
        reference: reference,
        gatewayPaymentId: gatewayPaymentId);
  }

  Future<void> saveWithdrawal(Withdrawal withdrawal) {
    return _financeService.saveWithdrawal(withdrawal);
  }

  Future<void> incrementDriverStats(
    String userId, {
    int trips = 0,
    double earnings = 0,
  }) {
    return _database.incrementDriverStats(userId,
        trips: trips, earnings: earnings);
  }

  Future<void> recalculateDriverRating(String userId) {
    return _database.recalculateDriverRating(userId);
  }

  Future<Map<String, dynamic>> saveToda(Map<String, dynamic> todaMap) {
    return _adminService.saveToda(todaMap);
  }

  Future<void> deleteToda(String todaId) {
    return _adminService.deleteToda(todaId);
  }

  Future<void> updateFareMatrix({
    required String vehicleType,
    required double baseFare,
    required double perKmRate,
  }) {
    return _adminService.updateFareMatrix(
        vehicleType: vehicleType, baseFare: baseFare, perKmRate: perKmRate);
  }

  Future<void> adminCancelTrip(String tripId, String reason) {
    return _database.adminCancelTrip(tripId, reason);
  }

  Future<void> adminRefundPayment(
      String paymentId, double amount, String reason) {
    return _financeService.adminRefundPayment(paymentId, amount, reason);
  }

  Future<void> saveTodaMembership({
    required String driverId,
    required String todaId,
  }) {
    return _database.saveTodaMembership(driverId: driverId, todaId: todaId);
  }

  Future<void> saveTodaAssociation(TodaAssociation association) {
    return _database.saveTodaAssociation(association);
  }

  Future<void> saveFareMatrix(FareMatrix matrix) {
    return _adminService.saveFareMatrix(matrix);
  }

  Future<void> createPassengerCloudProfile(String uid) {
    return _database.createPassengerCloudProfile(uid);
  }

  Future<void> acceptRide({
    required String rideId,
    required AppUser driver,
  }) {
    return _database.acceptRide(rideId: rideId, driver: driver);
  }

  Future<void> startTrip({
    required String rideId,
    double? driverLat,
    double? driverLng,
  }) {
    return _database.startTrip(
        rideId: rideId, driverLat: driverLat, driverLng: driverLng);
  }

  Future<Trip> completeTrip({
    required String rideId,
    required double actualFare,
  }) {
    return _database.completeTrip(rideId: rideId, actualFare: actualFare);
  }

  Future<void> rateDriver({
    required String rideId,
    required String passengerId,
    required String driverId,
    required double rating,
    String? comment,
  }) {
    return _ratingService.rateDriver(
        rideId: rideId,
        passengerId: passengerId,
        driverId: driverId,
        rating: rating,
        comment: comment);
  }

  Future<void> requestWithdrawal({
    required String driverId,
    required String driverName,
    required double amount,
    required String method,
    Map<String, dynamic>? accountDetails,
  }) {
    return _financeService.requestWithdrawal(
        driverId: driverId,
        driverName: driverName,
        amount: amount,
        method: method,
        accountDetails: accountDetails);
  }

  Future<void> approveDriver(String driverId) {
    return _database.approveDriver(driverId);
  }

  Future<int> repairApprovedDriverPhotos() async {
    return 0;
  }

  Future<void> rejectDriver(String driverId, String reason) {
    return _database.rejectDriver(driverId, reason);
  }

  Future<void> updateDriverLocation(String driverId, double lat, double lng) {
    return _database.updateDriverLocation(driverId, lat, lng);
  }

  Future<void> saveNotification(AppNotification notification) {
    return _notificationService.saveNotification(notification);
  }

  Future<void> pushNotification({
    required String userId,
    required String title,
    required String body,
    String? senderId,
    String? tripId,
  }) {
    return _notificationService.pushNotification(
        userId: userId,
        title: title,
        body: body,
        senderId: senderId,
        tripId: tripId);
  }

  Future<void> saveAdminAccount(AdminAccount admin) {
    return _adminService.saveAdminAccount(admin);
  }

  Future<String> createAdminAccountSecure(AdminAccount admin, String password) {
    return _adminService.createAdminAccountSecure(admin, password);
  }

  Future<void> updateAdminAccount(AdminAccount admin) {
    return _adminService.updateAdminAccount(admin);
  }

  Future<void> updateAdminProfile(String id, String fullName) {
    return _adminService.updateAdminProfile(id, fullName);
  }

  Future<void> deleteAdminAccount(String id) {
    return _adminService.deleteAdminAccount(id);
  }

  Future<Map<String, dynamic>> deletePassengerAccount(String id) {
    return _adminService.deletePassengerAccount(id);
  }

  Future<Map<String, dynamic>> deleteDriverAccount(String id) {
    return _adminService.deleteDriverAccount(id);
  }

  Future<bool> isEmailInUse(String email) {
    return auth.SupabaseAuthHelpers.instance.isEmailInUse(email);
  }

  Future<AdminAccount?> getAdminAccount(String id) {
    return _adminService.getAdminAccount(id);
  }

  Future<AdminAccount?> getAdminByEmail(String email) {
    return _adminService.getAdminByEmail(email);
  }

  Future<AdminAccount?> getAdminByMobile(String mobile) {
    return _adminService.getAdminByMobile(mobile);
  }

  Future<void> updateAdminStatus(String id, String status) {
    return _adminService.updateAdminStatus(id, status);
  }

  Future<void> updateAdminLastLogin(String id, DateTime timestamp) {
    return _adminService.updateAdminLastLogin(id, timestamp);
  }

  Future<String?> getAdminUserId() {
    return _adminService.getAdminUserId();
  }

  Future<void> markNotificationsRead(String userId) {
    return _notificationService.markNotificationsRead(userId);
  }

  Future<void> saveMagicLink(Map<String, dynamic> link) {
    return auth.SupabaseAuthHelpers.instance.saveMagicLink(link);
  }

  Future<({bool isValid, String? mobile, String? status})> verifyMagicLinkToken(
      String token) {
    return auth.SupabaseAuthHelpers.instance
        .verifyMagicLinkToken(token)
        .then((res) => res as ({bool isValid, String? mobile, String? status}));
  }

  Future<void> saveTransaction(WalletTransaction transaction) {
    return _financeService.saveTransaction(transaction);
  }

  Future<void> syncAllFromLocal(DatabaseService dbService) async {}

  Future<void> saveReport(FireReport report) {
    return _adminService.saveReport(report);
  }

  Future<void> updateReportStatus(
    String reportId,
    String status, {
    String? notes,
    String? resolution,
    String? adminId,
    String? adminName,
  }) {
    return _adminService.updateReportStatus(reportId, status,
        notes: notes,
        resolution: resolution,
        adminId: adminId,
        adminName: adminName);
  }

  Future<void> addReportNote(String reportId, String note) {
    return _adminService.addReportNote(reportId, note);
  }

  Future<void> createReport(FireReport report) {
    return _adminService.createReport(report);
  }

  Future<bool> rideExists(String rideId) {
    return _database.rideExists(rideId);
  }

  Future<bool> profileExists(String userId) {
    return _database.profileExists(userId);
  }

  Future<void> suspendDriver(String driverId, String reason) {
    return _database.suspendDriver(driverId, reason);
  }

  Future<void> reactivateDriver(String driverId) {
    return _database.reactivateDriver(driverId);
  }

  Future<int> repairApprovedDriverStatuses() async {
    return 0;
  }

  Future<void> commitBatch() async {}

  Future<void> setPassengerAccountStatus(
    String userId,
    String status, {
    String? reason,
  }) {
    return _database.setPassengerAccountStatus(userId, status, reason: reason);
  }

  Stream<List<NearbyDriver>> streamNearbyDrivers(
      {required double lat,
      required double lng,
      required double radiusKm,
      VehicleType? vehicleType}) {
    return _database.streamNearbyDrivers(
        lat: lat, lng: lng, radiusKm: radiusKm, vehicleType: vehicleType);
  }

  Future<List<DriverEarning>> fetchDriverEarningsOnce(String driverId) {
    return _database.fetchDriverEarningsOnce(driverId);
  }

  Stream<List<DriverEarning>> streamDriverEarnings(String driverId) {
    return _database.streamDriverEarnings(driverId);
  }

  Stream<DriverDailyEarningsSummary> streamDriverDailyEarningsToday(
      String driverId) {
    return _database.streamDriverDailyEarningsToday(driverId);
  }

  Stream<List<Trip>> streamRideHistoryForDriver(
    String driverId, {
    int limit = 100,
  }) {
    return _database.streamRideHistoryForDriver(driverId, limit: limit);
  }

  Stream<List<Trip>> streamRideHistoryForPassenger(
    String passengerId, {
    int limit = 100,
  }) {
    return _database.streamRideHistoryForPassenger(passengerId, limit: limit);
  }

  Future<Map<String, ({String name, String plate, String? photoUrl, int avatarColor})>>
      getDriverDisplayInfoBatch(Iterable<String> driverIds) {
    return _database.getDriverDisplayInfoBatch(driverIds);
  }

  Future<List<Withdrawal>> fetchWithdrawalsOnce(String driverId) {
    return _database.fetchWithdrawalsOnce(driverId);
  }

  Stream<List<Withdrawal>> streamWithdrawals(String driverId) {
    return _database.streamWithdrawals(driverId);
  }

  Stream<List<FireRating>> streamRatingsFor(String userId) {
    return _database.streamRatingsFor(userId);
  }

  Stream<List<AdminAccount>> streamAdminAccounts() {
    return _database.streamAdminAccounts();
  }

  Stream<List<FireReport>> streamAllReports(
      {String? status, String? type, String? searchQuery}) {
    // Reports are not UX-critical live state. Loading them once avoids a
    // Postgres Changes channel for a table outside the realtime publication.
    return _database.streamAllReports(
      status: status,
      type: type,
      searchQuery: searchQuery,
    );
  }

  Stream<List<Toda>> streamTodas(
      {String? status, String? searchQuery, int? limit}) {
    return _database.streamTodas().map((rows) {
      var todas = rows.map((row) {
        final createdAt = row['created_at'];
        return Toda(
          id: row['id']?.toString() ?? '',
          code: row['code']?.toString() ?? '',
          name: row['name']?.toString() ?? '',
          leader: row['president']?.toString() ?? '',
          contact: row['contact_number']?.toString() ?? '',
          area: row['city']?.toString() ?? '',
          active: row['is_active'] is bool ? row['is_active'] as bool : true,
          createdAt: createdAt is DateTime
              ? createdAt
              : DateTime.tryParse(createdAt?.toString() ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0),
        );
      }).toList();
      if (status != null && status != 'all') {
        final active = status == 'active';
        todas = todas.where((toda) => toda.active == active).toList();
      }
      final query = searchQuery?.trim().toLowerCase();
      if (query != null && query.isNotEmpty) {
        todas = todas
            .where((toda) =>
                toda.name.toLowerCase().contains(query) ||
                toda.id.toLowerCase().contains(query) ||
                toda.area.toLowerCase().contains(query))
            .toList();
      }
      return limit == null ? todas : todas.take(limit).toList();
    });
  }

  Stream<List<Trip>> streamAllRides(
      {String? status, String? method, String? searchQuery, int? limit}) {
    return _database.streamAllRides(
      status: status,
      searchQuery: searchQuery,
      limit: limit ?? 150,
    );
  }

  Stream<List<FirePayment>> streamAllPayments(
      {String? status, String? method, String? searchQuery, int? limit}) {
    return _database.streamAllPayments(
      status: status,
      method: method,
      searchQuery: searchQuery,
      limit: limit ?? 150,
    );
  }

  Stream<List<DriverEarning>> streamAllEarnings() {
    return _database.streamAllEarnings();
  }

  Stream<List<Trip>> streamIncomingRequestsForDriver(
      {required String driverId,
      required VehicleType vehicleType,
      double? lat,
      double? lng,
      double? radiusKm}) {
    return _database.streamIncomingRequestsForDriver(
      driverId: driverId,
      vehicleType: vehicleType,
      lat: lat,
      lng: lng,
      radiusKm: radiusKm ?? 10.0,
    );
  }

  Stream<List<AppUser>> streamPendingDrivers() {
    return _database.streamPendingDrivers();
  }

  Stream<List<DriverApplication>> streamPendingDriverApplications(
      {int? limit}) {
    // The canonical schema stores applications directly in public.drivers
    // using application_status. There is no verificationStatus column or
    // separate driver_applications table in Supabase.
    return _database.streamPendingDriverApplications(limit: limit);
  }

  Future<List<AdminAccount>> getAdminAccountsOnce() async {
    return _database.getAdminAccountsOnce();
  }

  Future<List<dynamic>> getFareMatrixOnce() async {
    return _database.getFareMatrixOnce();
  }

  Stream<List<dynamic>> streamFareMatrix() {
    return _database.streamFareMatrix();
  }
}

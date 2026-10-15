class AdminOverviewResponse {
  final int totalRides;
  final int activeRides;
  final int completedRides;
  final int cancelledRides;
  final int totalDrivers;
  final int activeDrivers;
  final int totalPassengers;
  final int pendingDrivers;
  final int openReports;
  final double revenueToday;
  final List<double> weeklyRevenue;

  AdminOverviewResponse({
    required this.totalRides,
    required this.activeRides,
    required this.completedRides,
    required this.cancelledRides,
    required this.totalDrivers,
    required this.activeDrivers,
    required this.totalPassengers,
    required this.pendingDrivers,
    required this.openReports,
    required this.revenueToday,
    required this.weeklyRevenue,
  });

  factory AdminOverviewResponse.fromJson(Map<String, dynamic> json) {
    return AdminOverviewResponse(
      totalRides: json['totalRides'] ?? 0,
      activeRides: json['activeRides'] ?? 0,
      completedRides: json['completedRides'] ?? 0,
      cancelledRides: json['cancelledRides'] ?? 0,
      totalDrivers: json['totalDrivers'] ?? 0,
      activeDrivers: json['activeDrivers'] ?? 0,
      totalPassengers: json['totalPassengers'] ?? 0,
      pendingDrivers: json['pendingDrivers'] ?? 0,
      openReports: json['openReports'] ?? 0,
      revenueToday: (json['revenueToday'] ?? 0).toDouble(),
      weeklyRevenue: List<double>.from(
          (json['weeklyRevenue'] as List? ?? []).map((e) => e.toDouble())),
    );
  }
}

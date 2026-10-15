/// Category / type of report submitted by passengers or drivers.
class ReportType {
  static const String safety = 'safety';
  static const String overcharging = 'overcharging';
  static const String lostItem = 'lost_item';
  static const String driverBehavior = 'driver_behavior';
  static const String passengerBehavior = 'passenger_behavior';
  static const String vehicleCondition = 'vehicle_condition';
  static const String appBug = 'app_bug';
  static const String other = 'other';

  static const List<String> all = [
    safety,
    overcharging,
    lostItem,
    driverBehavior,
    passengerBehavior,
    vehicleCondition,
    appBug,
    other,
  ];

  static bool isRideRelated(String type) {
    switch (type.toLowerCase()) {
      case safety:
      case overcharging:
      case lostItem:
      case driverBehavior:
      case passengerBehavior:
      case vehicleCondition:
        return true;
      default:
        return false;
    }
  }

  static String displayTitle(String type) {
    switch (type.toLowerCase()) {
      case safety:
        return 'Safety & Emergency';
      case overcharging:
        return 'Fare / Overcharging';
      case lostItem:
        return 'Lost & Found Item';
      case driverBehavior:
        return 'Driver Conduct';
      case passengerBehavior:
        return 'Passenger Conduct';
      case vehicleCondition:
        return 'Vehicle Condition';
      case appBug:
        return 'App / System Issue';
      default:
        return 'General Report';
    }
  }
}

/// Status of the report in the administration workflow.
class ReportStatus {
  static const String pending = 'pending';
  static const String underInvestigation = 'under_investigation';
  static const String resolved = 'resolved';
  static const String dismissed = 'dismissed';

  static const List<String> all = [
    pending,
    underInvestigation,
    resolved,
    dismissed,
  ];

  static String displayLabel(String status) {
    switch (status.toLowerCase()) {
      case pending:
        return 'Pending Review';
      case underInvestigation:
        return 'Under Investigation';
      case resolved:
        return 'Resolved';
      case dismissed:
        return 'Dismissed';
      default:
        return status;
    }
  }
}

/// Firestore model for platform incident, customer support, and dispute reports.
class FireReport {
  final String id;
  final String reporterId;
  final String reporterName;
  final String reporterRole; // passenger | driver | anonymous
  final String? reporterMobile;
  final String? reportedUserId;
  final String? reportedUserName;
  final String? reportedUserRole;
  final String? rideId;
  final String type; // safety | overcharging | lost_item | ...
  final String title;
  final String description;
  final String status; // pending | under_investigation | resolved | dismissed
  final String priority; // low | normal | high | urgent
  final List<String> adminNotes;
  final String? resolutionSummary;
  final String? resolvedByAdminId;
  final String? resolvedByAdminName;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? resolvedAt;

  const FireReport({
    required this.id,
    required this.reporterId,
    required this.reporterName,
    this.reporterRole = 'passenger',
    this.reporterMobile,
    this.reportedUserId,
    this.reportedUserName,
    this.reportedUserRole,
    this.rideId,
    required this.type,
    required this.title,
    required this.description,
    this.status = ReportStatus.pending,
    this.priority = 'normal',
    this.adminNotes = const [],
    this.resolutionSummary,
    this.resolvedByAdminId,
    this.resolvedByAdminName,
    required this.createdAt,
    this.updatedAt,
    this.resolvedAt,
  });

  FireReport copyWith({
    String? id,
    String? reporterId,
    String? reporterName,
    String? reporterRole,
    String? reporterMobile,
    String? reportedUserId,
    String? reportedUserName,
    String? reportedUserRole,
    String? rideId,
    String? type,
    String? title,
    String? description,
    String? status,
    String? priority,
    List<String>? adminNotes,
    String? resolutionSummary,
    String? resolvedByAdminId,
    String? resolvedByAdminName,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? resolvedAt,
  }) {
    return FireReport(
      id: id ?? this.id,
      reporterId: reporterId ?? this.reporterId,
      reporterName: reporterName ?? this.reporterName,
      reporterRole: reporterRole ?? this.reporterRole,
      reporterMobile: reporterMobile ?? this.reporterMobile,
      reportedUserId: reportedUserId ?? this.reportedUserId,
      reportedUserName: reportedUserName ?? this.reportedUserName,
      reportedUserRole: reportedUserRole ?? this.reportedUserRole,
      rideId: rideId ?? this.rideId,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      adminNotes: adminNotes ?? this.adminNotes,
      resolutionSummary: resolutionSummary ?? this.resolutionSummary,
      resolvedByAdminId: resolvedByAdminId ?? this.resolvedByAdminId,
      resolvedByAdminName: resolvedByAdminName ?? this.resolvedByAdminName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'reporterId': reporterId,
        'reporter_id': reporterId,
        'reporterName': reporterName,
        'reporter_name': reporterName,
        'reporterRole': reporterRole,
        'reporter_role': reporterRole,
        if (reporterMobile != null) 'reporterMobile': reporterMobile,
        if (reportedUserId != null) 'reportedUserId': reportedUserId,
        if (reportedUserId != null) 'reported_user_id': reportedUserId,
        if (reportedUserName != null) 'reportedUserName': reportedUserName,
        if (reportedUserName != null) 'reported_user_name': reportedUserName,
        if (reportedUserRole != null) 'reportedUserRole': reportedUserRole,
        if (rideId != null) 'rideId': rideId,
        if (rideId != null) 'ride_id': rideId,
        'type': type,
        'title': title,
        'description': description,
        'status': status,
        'priority': priority,
        'adminNotes': adminNotes,
        'admin_notes': adminNotes,
        if (resolutionSummary != null) ...{
          'resolutionSummary': resolutionSummary,
          'resolution_summary': resolutionSummary,
        },
        if (resolvedByAdminId != null) ...{
          'resolvedByAdminId': resolvedByAdminId,
          'resolved_by': resolvedByAdminId,
          'resolved_by_admin_id': resolvedByAdminId,
        },
        if (resolvedByAdminName != null) ...{
          'resolvedByAdminName': resolvedByAdminName,
          'resolved_by_admin_name': resolvedByAdminName,
        },
        'createdAt': createdAt.toUtc().toIso8601String(),
        'created_at': createdAt.toUtc().toIso8601String(),
        if (updatedAt != null) ...{
          'updatedAt': updatedAt!.toUtc().toIso8601String(),
          'updated_at': updatedAt!.toUtc().toIso8601String(),
        },
        if (resolvedAt != null) ...{
          'resolvedAt': resolvedAt!.toUtc().toIso8601String(),
          'resolved_at': resolvedAt!.toUtc().toIso8601String(),
        },
      };

  factory FireReport.fromMap(Map<String, dynamic> map, [String? docId]) {
    String readString(List<String> keys, [String def = '']) {
      for (final k in keys) {
        final val = map[k];
        if (val != null) {
          final str = val.toString().trim();
          if (str.isNotEmpty) return str;
        }
      }
      return def;
    }

    final notesRaw = map['adminNotes'] ?? map['admin_notes'];
    final List<String> notes = notesRaw is Iterable
        ? notesRaw.map((e) => e.toString()).toList()
        : <String>[];

    return FireReport(
      id: docId ?? readString(['id']),
      reporterId: readString(['reporterId', 'reporter_id']),
      reporterName: readString(['reporterName', 'reporter_name'], 'Unknown'),
      reporterRole: readString(['reporterRole', 'reporter_role'], 'passenger'),
      reporterMobile: map['reporterMobile']?.toString() ??
          map['reporter_mobile']?.toString(),
      reportedUserId: map['reportedUserId']?.toString() ??
          map['reported_user_id']?.toString(),
      reportedUserName: map['reportedUserName']?.toString() ??
          map['reported_user_name']?.toString(),
      reportedUserRole: map['reportedUserRole']?.toString() ??
          map['reported_user_role']?.toString(),
      rideId: map['rideId']?.toString() ?? map['ride_id']?.toString(),
      type: readString(['type'], ReportType.other),
      title: readString(['title'], 'Report'),
      description: readString(['description']),
      status: readString(['status'], ReportStatus.pending),
      priority: readString(['priority'], 'normal'),
      adminNotes: notes,
      resolutionSummary: map['resolutionSummary']?.toString() ??
          map['resolution_summary']?.toString(),
      resolvedByAdminId: map['resolvedByAdminId']?.toString() ??
          map['resolved_by_admin_id']?.toString() ??
          map['resolved_by']?.toString(),
      resolvedByAdminName: map['resolvedByAdminName']?.toString() ??
          map['resolved_by_admin_name']?.toString(),
      createdAt: _parseDate(map['createdAt'] ?? map['created_at']),
      updatedAt: _parseDateOrNull(map['updatedAt'] ?? map['updated_at']),
      resolvedAt: _parseDateOrNull(map['resolvedAt'] ?? map['resolved_at']),
    );
  }

  static DateTime _parseDate(Object? value) {
    if (value is DateTime) return value;
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  static DateTime? _parseDateOrNull(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

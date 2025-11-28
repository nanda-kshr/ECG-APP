class AdminDashboard {
  final Totals totals;
  final List<ReportItem> recentReports;

  AdminDashboard({required this.totals, required this.recentReports});

  factory AdminDashboard.fromJson(Map<String, dynamic> json) {
    // Data is already extracted by AdminService, so use json directly
    final totalsJson = json['totals'] ?? {};
    final recent = (json['recent_reports'] as List<dynamic>? ?? []);
    return AdminDashboard(
      totals:
          Totals.fromJson(totalsJson is Map<String, dynamic> ? totalsJson : {}),
      recentReports: recent
          .map((e) => ReportItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Totals {
  final int users;
  final int admins;
  final int doctors;
  final int technicians;
  final int reports;

  Totals({
    required this.users,
    required this.admins,
    required this.doctors,
    required this.technicians,
    required this.reports,
  });

  factory Totals.fromJson(Map<String, dynamic> json) {
    return Totals(
      users: int.tryParse(json['users']?.toString() ?? '0') ?? 0,
      admins: int.tryParse(json['admins']?.toString() ?? '0') ?? 0,
      doctors: int.tryParse(json['doctors']?.toString() ?? '0') ?? 0,
      technicians: int.tryParse(json['technicians']?.toString() ?? '0') ?? 0,
      reports: int.tryParse(json['reports']?.toString() ?? '0') ?? 0,
    );
  }
}

class ReportItem {
  final String id;
  final String patientName;
  final String? result;
  final String? technicianName;
  final String createdAt;

  ReportItem({
    required this.id,
    required this.patientName,
    this.result,
    this.technicianName,
    required this.createdAt,
  });

  factory ReportItem.fromJson(Map<String, dynamic> json) {
    return ReportItem(
      id: json['id']?.toString() ?? '',
      patientName: json['patient_name'] ?? '',
      result: json['result'],
      technicianName: json['technician_name'],
      createdAt: json['created_at'] ?? '',
    );
  }
}

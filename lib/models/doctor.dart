class Doctor {
  final int id;
  final String name;
  final String email;
  final String? department;
  final DateTime createdAt;
  final bool isDuty;
  final int? dutyRosterId;
  final DateTime? dutyDate;
  final String? shift;

  Doctor({
    required this.id,
    required this.name,
    required this.email,
    this.department,
    required this.createdAt,
    this.isDuty = false,
    this.dutyRosterId,
    this.dutyDate,
    this.shift,
  });

  factory Doctor.fromJson(Map<String, dynamic> json) {
    return Doctor(
      id: int.parse(json['id'].toString()),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      department: json['department']?.toString(),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      isDuty: json['is_duty'] == 1 ||
          json['is_duty'] == true ||
          json['is_duty'] == '1',
      dutyRosterId: json['duty_roster_id'] != null
          ? int.tryParse(json['duty_roster_id'].toString())
          : null,
      dutyDate: json['duty_date'] != null
          ? DateTime.tryParse(json['duty_date'])
          : null,
      shift: json['shift']?.toString(),
    );
  }

  bool get isOnDutyToday => dutyRosterId != null || isDuty;

  String get dutyStatusDisplay {
    if (isDuty) return 'On Duty (Flag)';
    if (dutyRosterId != null) {
      return 'On Duty${shift != null ? ' ($shift)' : ''}';
    }
    return 'Off Duty';
  }
}

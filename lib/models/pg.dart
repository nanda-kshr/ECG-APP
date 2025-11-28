class PG {
  final int id;
  final String name;
  final String email;
  final int createdBy; // doctor who created this PG
  final DateTime createdAt;
  final bool isDuty;

  PG({
    required this.id,
    required this.name,
    required this.email,
    required this.createdBy,
    required this.createdAt,
    this.isDuty = false,
  });

  factory PG.fromJson(Map<String, dynamic> json) {
    return PG(
      id: int.parse(json['id'].toString()),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      createdBy: int.parse(json['created_by']?.toString() ?? json['doctor_id']?.toString() ?? '0'),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      isDuty: json['is_duty'] == 1 || json['is_duty'] == true || json['is_duty'] == '1',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'is_duty': isDuty ? 1 : 0,
    };
  }
}

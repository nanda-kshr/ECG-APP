class Patient {
  final int id;
  final String patientId; // PAT20251023001 format
  final String name;
  final int? age;
  final String? gender;
  final String? contact;
  final DateTime createdAt;
  final String? imagePath; // Optional patient image/photo

  Patient({
    required this.id,
    required this.patientId,
    required this.name,
    this.age,
    this.gender,
    this.contact,
    required this.createdAt,
    this.imagePath,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) ?? 0 : 0,
      patientId: json['patient_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      age: json['age'] != null ? int.tryParse(json['age'].toString()) : null,
      gender: json['gender']?.toString(),
      contact: json['contact']?.toString() ?? json['phone']?.toString(),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      imagePath: json['image_path']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'name': name,
      'age': age,
      'gender': gender,
      'contact': contact,
      'created_at': createdAt.toIso8601String(),
      'image_path': imagePath,
    };
  }

  String get displayInfo {
    final ageStr = age != null ? ', $age years' : '';
    return '$name (ID: $patientId$ageStr)';
  }
}

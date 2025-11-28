class EcgImage {
  final String id;
  final String technicianId;
  final String imagePath;
  final String voiceNotePath;
  final DateTime uploadedAt;
  final String? assignedDoctorId;
  final String? doctorResponse;
  final DateTime? responseAt;
  final String patientInfo;

  EcgImage({
    required this.id,
    required this.technicianId,
    required this.imagePath,
    required this.voiceNotePath,
    required this.uploadedAt,
    this.assignedDoctorId,
    this.doctorResponse,
    this.responseAt,
    required this.patientInfo,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'technicianId': technicianId,
      'imagePath': imagePath,
      'voiceNotePath': voiceNotePath,
      'uploadedAt': uploadedAt.toIso8601String(),
      'assignedDoctorId': assignedDoctorId,
      'doctorResponse': doctorResponse,
      'responseAt': responseAt?.toIso8601String(),
      'patientInfo': patientInfo,
    };
  }

  factory EcgImage.fromJson(Map<String, dynamic> json) {
    return EcgImage(
      id: json['id'],
      technicianId: json['technicianId'],
      imagePath: json['imagePath'],
      voiceNotePath: json['voiceNotePath'],
      uploadedAt: DateTime.parse(json['uploadedAt']),
      assignedDoctorId: json['assignedDoctorId'],
      doctorResponse: json['doctorResponse'],
      responseAt: json['responseAt'] != null
          ? DateTime.parse(json['responseAt'])
          : null,
      patientInfo: json['patientInfo'],
    );
  }

  EcgImage copyWith({
    String? id,
    String? technicianId,
    String? imagePath,
    String? voiceNotePath,
    DateTime? uploadedAt,
    String? assignedDoctorId,
    String? doctorResponse,
    DateTime? responseAt,
    String? patientInfo,
  }) {
    return EcgImage(
      id: id ?? this.id,
      technicianId: technicianId ?? this.technicianId,
      imagePath: imagePath ?? this.imagePath,
      voiceNotePath: voiceNotePath ?? this.voiceNotePath,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      assignedDoctorId: assignedDoctorId ?? this.assignedDoctorId,
      doctorResponse: doctorResponse ?? this.doctorResponse,
      responseAt: responseAt ?? this.responseAt,
      patientInfo: patientInfo ?? this.patientInfo,
    );
  }
}

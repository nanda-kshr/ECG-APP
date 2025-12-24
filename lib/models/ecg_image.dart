class EcgImage {
  final String id;
  final String userId;
  final String imagePath;
  final String voiceNotePath;
  final DateTime uploadedAt;
  final String? assignedDoctorId;
  final String? doctorResponse;
  final DateTime? responseAt;
  final String patientInfo;

  EcgImage({
    required this.id,
    required this.userId,
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
      'userId': userId,
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
      userId: json['userId'],
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
    String? userId,
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
      userId: userId ?? this.userId,
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

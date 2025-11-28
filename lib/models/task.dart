class Task {
  final int id;
  final int patientId;
  final int technicianId;
  final int? assignedDoctorId;
  final int? assignedBy;
  final String status;
  final String priority;
  final String? technicianNotes;
  final String? adminNotes;
  final String? doctorFeedback;
  final DateTime? assignedAt;
  final DateTime? completedAt;
  final DateTime createdAt;

  // Joined fields
  final String? technicianName;
  final String? technicianEmail;
  final String? doctorName;
  final String? doctorEmail;
  final String? assignedByName;
  final String? patientName;
  final String? patientIdStr;
  final int? patientAge;
  // Last images for patient (API returns up to 10 latest)
  final List<PatientImage> patientLastImages;

  Task({
    required this.id,
    required this.patientId,
    required this.technicianId,
    this.assignedDoctorId,
    this.assignedBy,
    required this.status,
    required this.priority,
    this.technicianNotes,
    this.adminNotes,
    this.doctorFeedback,
    this.assignedAt,
    this.completedAt,
    required this.createdAt,
    this.technicianName,
    this.technicianEmail,
    this.doctorName,
    this.doctorEmail,
    this.assignedByName,
    this.patientName,
    this.patientIdStr,
    this.patientAge,
    this.patientLastImages = const [],
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: int.parse(json['id'].toString()),
      patientId: int.parse(json['patient_id'].toString()),
      technicianId: int.parse(json['technician_id'].toString()),
      assignedDoctorId: json['assigned_doctor_id'] != null
          ? int.parse(json['assigned_doctor_id'].toString())
          : null,
      assignedBy: json['assigned_by'] != null
          ? int.parse(json['assigned_by'].toString())
          : null,
      status: json['status']?.toString() ?? 'pending',
      priority: json['priority']?.toString() ?? 'normal',
      technicianNotes: json['technician_notes']?.toString(),
      adminNotes: json['admin_notes']?.toString(),
        doctorFeedback: (json['doctor_feedback'] ?? json['comment'])?.toString(),
      assignedAt: json['assigned_at'] != null
          ? DateTime.tryParse(json['assigned_at'])
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'])
          : null,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      technicianName: json['technician_name']?.toString(),
      technicianEmail: json['technician_email']?.toString(),
      doctorName: json['doctor_name']?.toString(),
      doctorEmail: json['doctor_email']?.toString(),
      assignedByName: json['assigned_by_name']?.toString(),
      patientName: json['patient_name']?.toString(),
      patientIdStr: json['patient_id_str']?.toString(),
      patientAge: json['patient_age'] != null
          ? int.tryParse(json['patient_age'].toString())
          : null,
        patientLastImages: (json['patient_last_images'] is List)
            ? (json['patient_last_images'] as List)
                .where((e) => e != null && e is Map)
                .map((e) => PatientImage.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList()
            : const [],
    );
  }

  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'Pending Assignment';
      case 'assigned':
        return 'Assigned';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String get priorityDisplay {
    switch (priority) {
      case 'low':
        return 'Low';
      case 'normal':
        return 'Normal';
      case 'high':
        return 'High';
      case 'urgent':
        return 'Urgent';
      default:
        return priority;
    }
  }
}

class PatientImage {
  final int imageId;
  final String imageName;
  final String? imagePath;
  final String? imageUrl;
  final String? comment;
  final DateTime? createdAt;
  final String? status;

  PatientImage({
    required this.imageId,
    required this.imageName,
    this.imagePath,
    this.imageUrl,
    this.comment,
    this.createdAt,
    this.status,
  });

  factory PatientImage.fromJson(Map<String, dynamic> json) {
    return PatientImage(
      imageId: int.parse(json['image_id'].toString()),
      imageName: json['image_name']?.toString() ?? '',
      imagePath: json['image_path']?.toString(),
      imageUrl: json['image_url']?.toString(),
      comment: json['comment']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      status: json['status']?.toString(),
    );
  }
}

import 'user.dart';
import 'ecg_image.dart';
import 'patient.dart';

class DummyData {
  static List<User> users = [
    User(
      id: 1,
      username: 'tech1',
      password: 'password',
      role: UserRole.technician,
      name: 'John Smith (Clinic Doctor)',
    ),
    User(
      id: 2,
      username: 'admin1',
      password: 'password',
      role: UserRole.admin,
      name: 'Sarah Johnson (Admin)',
    ),
    User(
      id: 3,
      username: 'doc1',
      password: 'password',
      role: UserRole.doctor,
      name: 'Dr. Michael Brown',
    ),
    User(
      id: 4,
      username: 'doc2',
      password: 'password',
      role: UserRole.doctor,
      name: 'Dr. Emily Davis',
    ),
    User(
      id: 5,
      username: 'tech2',
      password: 'password',
      role: UserRole.technician,
      name: 'Lisa Wilson (Clinic Doctor)',
    ),
  ];

  // Dummy Patients Data
  static List<Patient> patients = [
    Patient(
      id: 1,
      patientId: 'PAT20251023001',
      name: 'Jane Doe',
      age: 45,
      gender: 'female',
      contact: '+1-555-0101',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    Patient(
      id: 2,
      patientId: 'PAT20251023002',
      name: 'Robert Smith',
      age: 62,
      gender: 'male',
      contact: '+1-555-0102',
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
    ),
    Patient(
      id: 3,
      patientId: 'PAT20251023003',
      name: 'Mary Johnson',
      age: 38,
      gender: 'female',
      contact: '+1-555-0103',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    Patient(
      id: 4,
      patientId: 'PAT20251023004',
      name: 'David Wilson',
      age: 55,
      gender: 'male',
      contact: '+1-555-0104',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    Patient(
      id: 5,
      patientId: 'PAT20251023005',
      name: 'Jennifer Brown',
      age: 42,
      gender: 'female',
      contact: '+1-555-0105',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Patient(
      id: 6,
      patientId: 'PAT20251023006',
      name: 'Michael Davis',
      age: 58,
      gender: 'male',
      contact: '+1-555-0106',
      createdAt: DateTime.now().subtract(const Duration(hours: 12)),
    ),
    Patient(
      id: 7,
      patientId: 'PAT20251023007',
      name: 'Sarah Anderson',
      age: 34,
      gender: 'female',
      contact: '+1-555-0107',
      createdAt: DateTime.now().subtract(const Duration(hours: 8)),
    ),
    Patient(
      id: 8,
      patientId: 'PAT20251023008',
      name: 'James Martinez',
      age: 67,
      gender: 'male',
      contact: '+1-555-0108',
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
    ),
    Patient(
      id: 9,
      patientId: 'PAT20251023009',
      name: 'Patricia Taylor',
      age: 51,
      gender: 'female',
      contact: '+1-555-0109',
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    Patient(
      id: 10,
      patientId: 'PAT20251023010',
      name: 'Christopher Lee',
      age: 29,
      gender: 'male',
      contact: '+1-555-0110',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    Patient(
      id: 11,
      patientId: 'PAT20251023011',
      name: 'Linda White',
      age: 48,
      gender: 'female',
      contact: '+1-555-0111',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    Patient(
      id: 12,
      patientId: 'PAT20251023012',
      name: 'Daniel Harris',
      age: 72,
      gender: 'male',
      contact: '+1-555-0112',
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
    ),
  ];

  // Patient-Technician Mapping (which technician uploaded which patient)
  static Map<int, int> patientTechnicianMap = {
    1: 1, // Jane Doe uploaded by tech1
    2: 1, // Robert Smith uploaded by tech1
    3: 5, // Mary Johnson uploaded by tech2
    4: 1, // David Wilson uploaded by tech1
    5: 5, // Jennifer Brown uploaded by tech2
    6: 1, // Michael Davis uploaded by tech1
    7: 5, // Sarah Anderson uploaded by tech2
    8: 1, // James Martinez uploaded by tech1
    9: 5, // Patricia Taylor uploaded by tech2
    10: 1, // Christopher Lee uploaded by tech1
    11: 5, // Linda White uploaded by tech2
    12: 1, // Daniel Harris uploaded by tech1
  };

  // Patient Request Status (maps patient to doctor and response)
  static Map<int, PatientRequest> patientRequests = {
    1: PatientRequest(
      patientId: 1,
      assignedDoctorId: 3,
      status: 'completed',
      doctorResponse:
          'Normal sinus rhythm. No abnormalities detected. Patient shows healthy cardiac function.',
      responseAt: DateTime.now().subtract(const Duration(hours: 1)),
      assignedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    2: PatientRequest(
      patientId: 2,
      assignedDoctorId: 4,
      status: 'pending',
      assignedAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    3: PatientRequest(
      patientId: 3,
      status: 'pending',
    ),
    4: PatientRequest(
      patientId: 4,
      assignedDoctorId: 3,
      status: 'in_progress',
      assignedAt: DateTime.now().subtract(const Duration(minutes: 30)),
    ),
    5: PatientRequest(
      patientId: 5,
      status: 'pending',
    ),
    6: PatientRequest(
      patientId: 6,
      assignedDoctorId: 3,
      status: 'completed',
      doctorResponse:
          'Mild ST-segment elevation observed. Recommend further cardiac enzyme testing and follow-up within 24 hours.',
      responseAt: DateTime.now().subtract(const Duration(hours: 2)),
      assignedAt: DateTime.now().subtract(const Duration(hours: 10)),
    ),
    7: PatientRequest(
      patientId: 7,
      assignedDoctorId: 4,
      status: 'completed',
      doctorResponse:
          'Normal ECG findings. Patient cleared for physical activity.',
      responseAt: DateTime.now().subtract(const Duration(hours: 4)),
      assignedAt: DateTime.now().subtract(const Duration(hours: 7)),
    ),
    8: PatientRequest(
      patientId: 8,
      assignedDoctorId: 4,
      status: 'in_progress',
      assignedAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    9: PatientRequest(
      patientId: 9,
      status: 'pending',
    ),
    10: PatientRequest(
      patientId: 10,
      assignedDoctorId: 3,
      status: 'completed',
      doctorResponse:
          'Sinus tachycardia noted. Patient advised to reduce caffeine intake and manage stress levels.',
      responseAt: DateTime.now().subtract(const Duration(minutes: 45)),
      assignedAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    11: PatientRequest(
      patientId: 11,
      status: 'pending',
    ),
    12: PatientRequest(
      patientId: 12,
      assignedDoctorId: 4,
      status: 'in_progress',
      assignedAt: DateTime.now().subtract(const Duration(minutes: 20)),
    ),
  };

  static List<EcgImage> ecgImages = [
    EcgImage(
      id: '1',
      technicianId: '1',
      imagePath: 'dummy_ecg_1.jpg',
      voiceNotePath: 'voice_note_1.wav',
      uploadedAt: DateTime.now().subtract(const Duration(hours: 2)),
      assignedDoctorId: '3',
      patientInfo: 'Patient: Jane Doe, Age: 45, ID: P001',
      doctorResponse: 'Normal sinus rhythm. No abnormalities detected.',
      responseAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    EcgImage(
      id: '2',
      technicianId: '1',
      imagePath: 'dummy_ecg_2.jpg',
      voiceNotePath: 'voice_note_2.wav',
      uploadedAt: DateTime.now().subtract(const Duration(hours: 4)),
      assignedDoctorId: '4',
      patientInfo: 'Patient: Robert Smith, Age: 62, ID: P002',
    ),
    EcgImage(
      id: '3',
      technicianId: '5',
      imagePath: 'dummy_ecg_3.jpg',
      voiceNotePath: 'voice_note_3.wav',
      uploadedAt: DateTime.now().subtract(const Duration(hours: 6)),
      patientInfo: 'Patient: Mary Johnson, Age: 38, ID: P003',
    ),
    EcgImage(
      id: '4',
      technicianId: '1',
      imagePath: 'dummy_ecg_4.jpg',
      voiceNotePath: 'voice_note_4.wav',
      uploadedAt: DateTime.now().subtract(const Duration(minutes: 30)),
      assignedDoctorId: '3',
      patientInfo: 'Patient: David Wilson, Age: 55, ID: P004',
    ),
    EcgImage(
      id: '5',
      technicianId: '5',
      imagePath: 'dummy_ecg_5.jpg',
      voiceNotePath: 'voice_note_5.wav',
      uploadedAt: DateTime.now().subtract(const Duration(hours: 8)),
      patientInfo: 'Patient: Jennifer Brown, Age: 42, ID: P005',
    ),
  ];

  static User? findUser(String username, String password) {
    try {
      return users.firstWhere(
        (user) => user.username == username && user.password == password,
      );
    } catch (e) {
      return null;
    }
  }

  static List<User> getDoctors() {
    return users.where((user) => user.role == UserRole.doctor).toList();
  }

  static List<EcgImage> getImagesForTechnician(String technicianId) {
    return ecgImages
        .where((image) => image.technicianId == technicianId)
        .toList();
  }

  static List<EcgImage> getImagesForDoctor(String doctorId) {
    return ecgImages
        .where((image) => image.assignedDoctorId == doctorId)
        .toList();
  }

  static void assignDoctorToImage(String imageId, String doctorId) {
    int index = ecgImages.indexWhere((image) => image.id == imageId);
    if (index != -1) {
      ecgImages[index] = ecgImages[index].copyWith(assignedDoctorId: doctorId);
    }
  }

  static void addDoctorResponse(String imageId, String response) {
    int index = ecgImages.indexWhere((image) => image.id == imageId);
    if (index != -1) {
      ecgImages[index] = ecgImages[index].copyWith(
        doctorResponse: response,
        responseAt: DateTime.now(),
      );
    }
  }

  static void addNewImage(EcgImage image) {
    ecgImages.add(image);
  }

  // Patient-related methods
  static List<Patient> getAllPatients() {
    return patients;
  }

  static Patient? getPatientById(int id) {
    try {
      return patients.firstWhere((patient) => patient.id == id);
    } catch (e) {
      return null;
    }
  }

  static Patient? getPatientByPatientId(String patientId) {
    try {
      return patients.firstWhere((patient) => patient.patientId == patientId);
    } catch (e) {
      return null;
    }
  }

  static List<Patient> getPatientsForDoctor(int doctorId) {
    List<Patient> assignedPatients = [];
    patientRequests.forEach((patientId, request) {
      if (request.assignedDoctorId == doctorId) {
        final patient = getPatientById(patientId);
        if (patient != null) {
          assignedPatients.add(patient);
        }
      }
    });
    return assignedPatients;
  }

  static List<Patient> getPatientsForTechnician(int technicianId) {
    List<Patient> uploadedPatients = [];
    patientTechnicianMap.forEach((patientId, techId) {
      if (techId == technicianId) {
        final patient = getPatientById(patientId);
        if (patient != null) {
          uploadedPatients.add(patient);
        }
      }
    });
    return uploadedPatients;
  }

  static PatientRequest? getPatientRequest(int patientId) {
    return patientRequests[patientId];
  }

  static void assignPatientToDoctor(int patientId, int doctorId) {
    if (patientRequests.containsKey(patientId)) {
      patientRequests[patientId] = PatientRequest(
        patientId: patientId,
        assignedDoctorId: doctorId,
        status: 'assigned',
        assignedAt: DateTime.now(),
      );
    } else {
      patientRequests[patientId] = PatientRequest(
        patientId: patientId,
        assignedDoctorId: doctorId,
        status: 'assigned',
        assignedAt: DateTime.now(),
      );
    }
  }

  static void updatePatientResponse(int patientId, String response) {
    if (patientRequests.containsKey(patientId)) {
      final current = patientRequests[patientId]!;
      patientRequests[patientId] = PatientRequest(
        patientId: current.patientId,
        assignedDoctorId: current.assignedDoctorId,
        status: 'completed',
        doctorResponse: response,
        responseAt: DateTime.now(),
        assignedAt: current.assignedAt,
      );
    }
  }
}

// PatientRequest class to track patient assignment and doctor response
class PatientRequest {
  final int patientId;
  final int? assignedDoctorId;
  final String status; // 'pending', 'assigned', 'in_progress', 'completed'
  final String? doctorResponse;
  final DateTime? responseAt;
  final DateTime? assignedAt;

  PatientRequest({
    required this.patientId,
    this.assignedDoctorId,
    required this.status,
    this.doctorResponse,
    this.responseAt,
    this.assignedAt,
  });
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../services/auth_service.dart';
import '../config.dart';
import '../models/patient.dart';
import 'user_upload_screen.dart';

class PatientTasksScreen extends StatefulWidget {
  final List<Task> tasks;
  final String patientName;
  final String patientIdStr;

  const PatientTasksScreen({
    Key? key,
    required this.tasks,
    required this.patientName,
    required this.patientIdStr,
  }) : super(key: key);

  @override
  State<PatientTasksScreen> createState() => _PatientTasksScreenState();
}

class _PatientTasksScreenState extends State<PatientTasksScreen> {
  // Map<ImageId, Controller>
  final Map<int, TextEditingController> _imageFeedbackControllers = {};
  // Map<TaskId, Controller> for overall task feedback
  final Map<int, TextEditingController> _taskFeedbackControllers = {};

  final ScrollController _scrollController = ScrollController();
  bool _isUpdating = false;
  String? _errorMessage;
  String? _successMessage;
  int? _selectedImageIndex;

  // App theme colors
  static const Color _primaryColor = Color(0xFF1976D2); // Blue
  static const Color _primaryDark = Color(0xFF1565C0);
  static const Color _primaryLight = Color(0xFFBBDEFB);
  static const Color _backgroundColor =
      Color(0xFFE3F2FD); // Light blue background

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    // No need to scroll - reversed ListView naturally starts at bottom
  }

  void _initializeControllers() {
    for (var task in widget.tasks) {
      // Task level feedback
      _taskFeedbackControllers[task.id] = TextEditingController(
        text: task.doctorFeedback ?? '',
      );

      // Image level feedback
      for (var image in task.patientLastImages) {
        _imageFeedbackControllers[image.imageId] = TextEditingController(
          text: image.comment ?? '',
        );
      }
    }
  }

  @override
  void didUpdateWidget(PatientTasksScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tasks != widget.tasks) {
      _initializeControllers();
    }
  }

  void _scrollToBottom() {
    // Use a small delay to ensure images start loading and content is laid out
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  String _getImageUrl(PatientImage image) {
    if (image.imageUrl != null && image.imageUrl!.isNotEmpty) {
      return image.imageUrl!;
    }
    String baseUrl = apiBaseUrl;
    if (!baseUrl.endsWith('/')) {
      baseUrl = '$baseUrl/';
    }
    return '${baseUrl}get_image.php?image_id=${image.imageId}&download=1';
  }

  void _showFullScreenImage(
      BuildContext context, String imageUrl, PatientImage image) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              image.imageName,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image,
                            size: 64, color: Colors.white54),
                        SizedBox(height: 16),
                        Text(
                          'Failed to load image',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return '';
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final day = dateTime.day.toString().padLeft(2, '0');
    return '$day - ${months[dateTime.month - 1]} - ${dateTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.currentUser;
    final isDoctor = currentUser?.role.name == 'doctor';
    final isAdmin = currentUser?.role.name == 'admin';
    final isUser = currentUser?.role.name == 'user';
    final isPg = currentUser?.role.name == 'pg';
    // Treat user and PG roles as patient-like view (no input)
    final isPatient = isUser || isPg;
    final canEditFeedback = (isDoctor == true) || (isAdmin == true);

    // Sort tasks by creation date (newest first for reversed ListView)
    final sortedTasks = List<Task>.from(widget.tasks);
    sortedTasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: _primaryLight,
              radius: 20,
              child: Text(
                widget.patientName.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: _primaryDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.patientName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'ID: ${widget.patientIdStr} • ${sortedTasks.length} ECG',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Upload ECG',
            onPressed: () {
              int pId = 0;
              if (widget.tasks.isNotEmpty) {
                pId = widget.tasks.first.patientId;
              }
              final patient = Patient(
                id: pId,
                patientId: widget.patientIdStr,
                name: widget.patientName,
                createdAt: DateTime.now(),
              );
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => UserUploadScreen(
                    preSelectedPatient: patient,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat messages area
          Expanded(
            child: ListView(
              controller: _scrollController,
              reverse: true, // Start from bottom - newest task visible first
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                // Note: Items are rendered in reverse order due to reverse: true
                // So we put the bottom items first in the children list

                // Messages (at bottom, so listed first)
                if (_errorMessage != null)
                  _buildSystemMessage(_errorMessage!, isError: true),
                if (_successMessage != null)
                  _buildSystemMessage(_successMessage!, isSuccess: true),

                const SizedBox(height: 20),

                // ECG (newest first due to reverse, which appears at bottom)
                // Serial numbers: newest = 1, counting up for older tasks
                ...sortedTasks.asMap().entries.map((entry) {
                  final index = entry.key;
                  final task = entry.value;
                  // Since list is sorted newest first, serial is Total - Index
                  // e.g. Count=5. Index=0 (Newest) -> 5. Index=4 (Oldest) -> 1.
                  final serialNumber = sortedTasks.length - index;
                  return _buildTaskSection(
                    task,
                    serialNumber: serialNumber,
                    canEditFeedback: canEditFeedback,
                    isPatient: isPatient,
                    isUser: isUser,
                  );
                }),

                const SizedBox(height: 12),

                // Patient info bubble (at top, so listed last)
                _buildInfoBubble(
                  title: 'Patient Information',
                  items: [
                    ('Patient ID', widget.patientIdStr),
                    ('Name', widget.patientName),
                    if (sortedTasks.isNotEmpty &&
                        sortedTasks.first.patientAge != null)
                      ('Age', '${sortedTasks.first.patientAge} years'),
                  ],
                  isFromMe: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskSection(
    Task task, {
    required int serialNumber,
    required bool canEditFeedback,
    required bool isPatient,
    required bool isUser,
  }) {
    // Images are now correctly associated by task_id from the API
    final sortedImages = List<PatientImage>.from(task.patientLastImages);
    sortedImages.sort((a, b) {
      if (a.createdAt == null && b.createdAt == null) return 0;
      if (a.createdAt == null) return -1;
      if (b.createdAt == null) return 1;
      return a.createdAt!.compareTo(b.createdAt!);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Task Header (Date/Time Separator)
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$serialNumber • ${_formatDate(task.createdAt)} at ${_formatTime(task.createdAt)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ),
        ),

        // Images for this task
        if (sortedImages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildGroupedImagesBubble(
              images: sortedImages,
              isDoctor: canEditFeedback,
              isPatient: isPatient,
              isUser: isUser, // Important if isUser logic inside bubble needed
              userNotes: task.userNotes,
              userName: task.userName,
              taskId: task.id, // Pass task ID for context if needed
            ),
          ),

        // Admin Notes
        if (task.adminNotes != null && task.adminNotes!.isNotEmpty) ...[
          _buildMessageBubble(
            sender: 'Admin',
            message: task.adminNotes!,
            time: task.assignedAt,
            isFromMe: false,
            senderRole: 'Admin Notes',
            bubbleColor: const Color(0xFFE3F2FD),
          ),
          const SizedBox(height: 8),
        ],

        // Doctor Task Level Opinion (if needed outside images)
        // Currently your design puts feedback inside images or specific boxes.
        // If there's an overall task feedback separate from image feedback, it goes here.
        if (task.doctorFeedback != null && task.doctorFeedback!.isNotEmpty) ...[
          _buildMessageBubble(
            sender: task.doctorName ?? 'Doctor',
            message: task.doctorFeedback!,
            time: task.completedAt,
            isFromMe: false,
            senderRole: 'Doctor Opinion (Task)',
            bubbleColor: Colors.white,
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  // REFACTORED: Group all images into one bubble
  Widget _buildGroupedImagesBubble({
    required List<PatientImage> images,
    required bool isDoctor,
    required bool isPatient,
    required bool isUser,
    String? userNotes,
    String? userName,
    required int taskId,
  }) {
    if (images.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Iterate over all images
            ...images.asMap().entries.map((entry) {
              final index = entry.key;
              final image = entry.value;
              // Unique global index can be tricky here if tracking selection across multiple tasks
              // We'll trust local context or mapped IDs.
              final isLastImage = index == images.length - 1;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSingleImageItem(
                    image: image,
                    taskId: taskId,
                    isDoctor: isDoctor,
                    isPatient: isPatient,
                    isUser: isUser,
                    isLastImage: isLastImage,
                  ),
                  // Divider between images (if not last)
                  if (!isLastImage)
                    const Divider(
                        height: 24, thickness: 1, color: Color(0xFFEEEEEE)),
                ],
              );
            }),

            // User notes section - ONLY SHOWN ONCE AT BOTTOM
            if (userNotes != null && userNotes.isNotEmpty) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.note_alt,
                          size: 14,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Clinic Doctor Notes',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        if (userName != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            '• $userName',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.shade200,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        userNotes,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Helper for rendering a single image content within the group bubble
  Widget _buildSingleImageItem({
    required PatientImage image,
    required int taskId,
    required bool isDoctor,
    required bool isPatient,
    required bool isUser,
    required bool isLastImage,
  }) {
    final imageUrl = _getImageUrl(image);
    final controller = _imageFeedbackControllers[image.imageId];
    // Simple selection tracking (might conflict if multiple tasks open, but OK for now)
    final isSelected = _selectedImageIndex == image.imageId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image header
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
            children: [
              Icon(
                Icons.image,
                size: 16,
                color: _primaryColor.withOpacity(0.7),
              ),
              const SizedBox(width: 6),
              if (image.createdAt != null)
                Text(
                  '${_formatDate(image.createdAt)} • ${_formatTime(image.createdAt)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
            ],
          ),
        ),

        // Image
        GestureDetector(
          onTap: () => _showFullScreenImage(context, imageUrl, image),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(0)),
            child: Image.network(
              imageUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 200,
                  color: Colors.grey.shade100,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: _primaryColor,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 200,
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Failed to load image',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // Tap to view hint
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(
                Icons.touch_app,
                size: 14,
                color: Colors.grey.shade500,
              ),
              const SizedBox(width: 4),
              Text(
                'Tap to view full screen',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Opinion section
        if (isLastImage && isDoctor) ...[
          // If feedback already exists for this image, show it read-only
          if (image.comment != null && image.comment!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Opinion',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      image.comment!,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isLastImage) ...[
            // Doctor input box - ONLY for last image
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Opinion',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? _primaryColor
                                  : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: TextField(
                            controller: controller, // Bound to imageId
                            maxLines: 3,
                            minLines: 1,
                            decoration: const InputDecoration(
                              hintText: 'Enter opinion...',
                              hintStyle: TextStyle(fontSize: 13),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                            ),
                            style: const TextStyle(fontSize: 13),
                            onTap: () => setState(
                                () => _selectedImageIndex = image.imageId),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: _primaryColor,
                        borderRadius: BorderRadius.circular(24),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: _isUpdating
                              ? null
                              : () =>
                                  _submitImageFeedback(taskId, image.imageId),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: _isUpdating
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.send,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ] else if (isLastImage && isPatient) ...[
          // Patient view
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (image.comment != null && image.comment!.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.medical_services,
                        size: 14,
                        color: _primaryColor.withOpacity(0.7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Doctor\'s Opinion',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      image.comment!,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ] else if (image.status == 'closed') ...[
                  // Closed status - show request closed message with emergency contact
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Icon(
                                Icons.info_outline,
                                size: 20,
                                color: Colors.red.shade700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'This request has been closed due to high patient load. In case of emergency, please contact Saveetha Emergency.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red.shade700,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final Uri phoneUri =
                                  Uri(scheme: 'tel', path: '04466726612');
                              if (await canLaunchUrl(phoneUri)) {
                                await launchUrl(phoneUri);
                              }
                            },
                            icon: const Icon(Icons.phone, size: 18),
                            label: const Text('Call (044) 6672 6612'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.pending,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Awaiting doctor\'s feedback',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSystemMessage(String text,
      {bool isError = false, bool isSuccess = false}) {
    Color bgColor = Colors.white.withOpacity(0.9);
    Color textColor = Colors.grey.shade700;
    if (isError) {
      bgColor = Colors.red.shade100;
      textColor = Colors.red.shade800;
    } else if (isSuccess) {
      bgColor = Colors.green.shade100;
      textColor = Colors.green.shade800;
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: textColor,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildInfoBubble({
    required String title,
    required List<(String, String)> items,
    required bool isFromMe,
  }) {
    return Align(
      alignment: isFromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: _primaryColor,
              ),
            ),
            const Divider(height: 12),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          item.$1,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item.$2,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble({
    required String sender,
    required String message,
    required DateTime? time,
    required bool isFromMe,
    required String senderRole,
    Color bubbleColor = Colors.white,
  }) {
    return Align(
      alignment: isFromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isFromMe ? 12 : 0),
            bottomRight: Radius.circular(isFromMe ? 0 : 12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  senderRole,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor.withOpacity(0.8),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '• $sender',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                _formatTime(time),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Submit per-image feedback (doctor)
  Future<void> _submitImageFeedback(int taskId, int imageId) async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) {
      setState(() => _errorMessage = 'Not logged in');
      return;
    }

    final controller = _imageFeedbackControllers[imageId];
    if (controller == null) {
      setState(() => _errorMessage = 'No feedback controller found');
      return;
    }

    final comment = controller.text.trim();

    setState(() {
      _isUpdating = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final result = await TaskService.updateImageComment(
      taskId: taskId,
      imageId: imageId,
      doctorId: currentUser.id,
      comment: comment,
      applyToAll: true,
    );

    setState(() {
      _isUpdating = false;
      if (result['success'] == true) {
        _successMessage = result['message'] ?? 'Opinion submitted';
        // Go back to previous screen (Dashboard)
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) Navigator.of(context).pop(true);
        });
      } else {
        _errorMessage = result['error'] ?? 'Failed to submit feedback';
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (var controller in _imageFeedbackControllers.values) {
      controller.dispose();
    }
    for (var controller in _taskFeedbackControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../services/auth_service.dart';
import '../config.dart';

class TaskDetailScreen extends StatefulWidget {
  final Task task;

  const TaskDetailScreen({Key? key, required this.task}) : super(key: key);

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final Map<int, TextEditingController> _imageFeedbackControllers = {};
  final _overallFeedbackController = TextEditingController();
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
    _overallFeedbackController.text = widget.task.doctorFeedback ?? '';
    // Initialize feedback controllers for each image
    for (var image in widget.task.patientLastImages) {
      _imageFeedbackControllers[image.imageId] = TextEditingController(
        text: image.comment ?? '',
      );
    }
    // Scroll to bottom after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
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

  String _getAllFeedback() {
    final buffer = StringBuffer();
    if (_overallFeedbackController.text.trim().isNotEmpty) {
      buffer.writeln(_overallFeedbackController.text.trim());
    }
    for (var image in widget.task.patientLastImages) {
      final controller = _imageFeedbackControllers[image.imageId];
      if (controller != null && controller.text.trim().isNotEmpty) {
        buffer.writeln('\n[${image.imageName}]: ${controller.text.trim()}');
      }
    }
    return buffer.toString().trim();
  }

  // ignore: unused_element
  Future<void> _updateStatus(String newStatus) async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) {
      setState(() => _errorMessage = 'Not logged in');
      return;
    }

    setState(() {
      _isUpdating = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final feedbackText = _getAllFeedback();

    Map<String, dynamic> result;
    final isDoctor = currentUser.role.name == 'doctor';
    if (isDoctor && newStatus == 'completed') {
      result = await TaskService.dutyUpdateTask(
        taskId: widget.task.id,
        doctorId: currentUser.id,
        comment: feedbackText,
      );
      if (result['success'] != true) {
        result = await TaskService.updateTask(
          taskId: widget.task.id,
          userId: currentUser.id,
          status: newStatus,
          feedback: feedbackText,
        );
      }
    } else {
      result = await TaskService.updateTask(
        taskId: widget.task.id,
        userId: currentUser.id,
        status: newStatus,
        feedback: feedbackText,
      );
    }

    setState(() {
      _isUpdating = false;
      if (result['success'] == true) {
        _successMessage = result['message'] ?? 'Opinion updated successfully';
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop();
        });
      } else {
        _errorMessage = result['error'] ?? 'Failed to update task';
      }
    });
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
    final task = widget.task;
    final currentUser = AuthService.currentUser;
    final isDoctor = currentUser?.role.name == 'doctor';
    final isAdmin = currentUser?.role.name == 'admin';
    final isUser = currentUser?.role.name == 'user';
    final isPg = currentUser?.role.name == 'pg';
    // Treat user and PG roles as patient-like view (no input)
    final isPatient = isUser || isPg;
    final canEditFeedback = (isDoctor == true) || (isAdmin == true);

    // Sort images in descending order (newest first at bottom like WhatsApp)
    final sortedImages = List<PatientImage>.from(task.patientLastImages);
    sortedImages.sort((a, b) {
      if (a.createdAt == null && b.createdAt == null) return 0;
      if (a.createdAt == null) return -1;
      if (b.createdAt == null) return 1;
      return a.createdAt!
          .compareTo(b.createdAt!); // Ascending so newest at bottom
    });

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
                task.patientName?.substring(0, 1).toUpperCase() ?? 'P',
                style: TextStyle(
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
                    task.patientName ?? 'Patient',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Task #${task.id} • ${task.statusDisplay}',
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
      ),
      body: Column(
        children: [
          // Chat messages area
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                // Task info header bubble
                _buildSystemMessage(
                  'ECG created on ${_formatDate(task.createdAt)} at ${_formatTime(task.createdAt)}',
                ),
                const SizedBox(height: 8),

                // Patient info bubble
                _buildInfoBubble(
                  title: 'Patient Information',
                  items: [
                    ('Patient ID', task.patientIdStr ?? 'N/A'),
                    ('Name', task.patientName ?? 'N/A'),
                    if (task.patientAge != null)
                      ('Age', '${task.patientAge} years'),
                    ('Clinic Doctor', task.userName ?? 'N/A'),
                    ('Doctor', task.doctorName ?? 'N/A'),
                  ],
                  isFromMe: false,
                ),
                const SizedBox(height: 12),

                // ECG Images as chat bubbles (sorted ascending so newest at bottom)
                if (sortedImages.isNotEmpty) ...[
                  _buildSystemMessage('ECG Images (${sortedImages.length})'),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildGroupedImagesBubble(
                      images: sortedImages,
                      isDoctor: canEditFeedback,
                      isPatient: isPatient,
                      isUser: isUser,
                      userNotes: task.userNotes,
                      userName: task.userName,
                    ),
                  ),
                ],

                // Admin notes
                if (task.adminNotes != null && task.adminNotes!.isNotEmpty) ...[
                  _buildMessageBubble(
                    sender: 'Admin',
                    message: task.adminNotes!,
                    time: task.assignedAt,
                    isFromMe: false,
                    senderRole: 'Admin Notes',
                    bubbleColor: const Color(0xFFE3F2FD),
                  ),
                  const SizedBox(height: 12),
                ],

                // Doctor feedback (for patients - read only)
                if (isPatient &&
                    task.doctorFeedback != null &&
                    task.doctorFeedback!.isNotEmpty) ...[
                  _buildMessageBubble(
                    sender: task.doctorName ?? 'Doctor',
                    message: task.doctorFeedback!,
                    time: task.completedAt,
                    isFromMe: false,
                    senderRole: 'Doctor Feedback',
                    bubbleColor: const Color(0xFFFFFFFF),
                  ),
                  const SizedBox(height: 12),
                ],

                // Messages
                if (_errorMessage != null)
                  _buildSystemMessage(_errorMessage!, isError: true),
                if (_successMessage != null)
                  _buildSystemMessage(_successMessage!, isSuccess: true),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
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

  // REFACTORED: Group all images into one bubble
  Widget _buildGroupedImagesBubble({
    required List<PatientImage> images,
    required bool isDoctor,
    required bool isPatient,
    required bool isUser,
    String? userNotes,
    String? userName,
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
              final isLastImage = index == images.length - 1;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSingleImageItem(
                    image: image,
                    index: index,
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
    required int index,
    required bool isDoctor,
    required bool isPatient,
    required bool isUser,
    required bool isLastImage,
  }) {
    final imageUrl = _getImageUrl(image);
    final controller = _imageFeedbackControllers[image.imageId];
    final isSelected = _selectedImageIndex == index;

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
              // Expanded(
              //   child: Text(
              //     image.imageName,
              //     style: TextStyle(
              //       fontSize: 13,
              //       fontWeight: FontWeight.w600,
              //       color: _primaryColor,
              //     ),
              //     maxLines: 1,
              //     overflow: TextOverflow.ellipsis,
              //   ),
              // ),
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

        // Feedback section
        if (isLastImage && isDoctor) ...[
          // If feedback already exists for this image, show it read-only
          if (image.comment != null && image.comment!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Feedback (submitted)',
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
          ] else ...[
            // Doctor input box with reply button
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Feedback',
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
                            controller: controller,
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
                            onTap: () =>
                                setState(() => _selectedImageIndex = index),
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
                              : () => _submitImageFeedback(image.imageId),
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
        ] else if (isPatient) ...[
          // Patient view - show feedback as label
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
                        'Doctor\'s Feedback',
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

  @override
  void dispose() {
    _scrollController.dispose();
    _overallFeedbackController.dispose();
    for (var controller in _imageFeedbackControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // Submit per-image feedback (doctor)
  Future<void> _submitImageFeedback(int imageId) async {
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
      taskId: widget.task.id,
      imageId: imageId,
      doctorId: currentUser.id,
      comment: comment,
    );

    setState(() {
      _isUpdating = false;
      if (result['success'] == true) {
        _successMessage = result['message'] ?? 'Feedback submitted';
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop();
        });
      } else {
        _errorMessage = result['error'] ?? 'Failed to submit feedback';
      }
    });
    // Scroll to bottom to show the message
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }
}

import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import 'task_detail_screen.dart';

class TaskListScreen extends StatefulWidget {
  final String title;
  final String? filterStatus;

  const TaskListScreen({
    super.key,
    required this.title,
    this.filterStatus,
  });

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<Task> _tasks = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tasks = await TaskService.listTasks(status: widget.filterStatus);
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load tasks: $e';
        _isLoading = false;
      });
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'normal':
        return Colors.blue;
      case 'low':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTasks,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadTasks,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _tasks.isEmpty
                  ? const Center(child: Text('No tasks found'))
                  : RefreshIndicator(
                      onRefresh: _loadTasks,
                      child: ListView.builder(
                        itemCount: _tasks.length,
                        itemBuilder: (context, index) {
                          final task = _tasks[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    _getPriorityColor(task.priority),
                                child: Text(
                                  task.priority[0].toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                  '${task.patientName ?? 'Unknown Patient'} - ${task.patientIdStr ?? 'ID Unknown'}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text('Doctor: ${task.doctorName ?? ''}'),
                                  Text('Clinic Doctor: ${task.userName ?? ''}'),
                                  const SizedBox(height: 4),
                                  Text(
                                    task.createdAt.toString().substring(0, 16),
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                  // If task is completed and has doctor feedback, show it (read-only)
                                  if (task.status == 'completed' &&
                                      (task.doctorFeedback != null &&
                                          task.doctorFeedback!.isNotEmpty)) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.04),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        task.doctorFeedback!,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              isThreeLine: true,
                              trailing:
                                  const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        TaskDetailScreen(task: task),
                                  ),
                                );
                                _loadTasks(); // Refresh after viewing detail
                              },
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

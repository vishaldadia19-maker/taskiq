import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class AllTasksScreen extends StatefulWidget {
  final int userId;

  const AllTasksScreen({
    super.key,
    required this.userId,
  });

  @override
  State<AllTasksScreen> createState() => _AllTasksScreenState();
}

class _AllTasksScreenState extends State<AllTasksScreen> {
  List tasks = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMore = true;
  int offset = 0;
  final int limit = 30;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadAllTasks(reset: true);

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !isLoadingMore &&
          hasMore) {
        _loadAllTasks();
      }
    });
  }

  Future<void> _loadAllTasks({bool reset = false}) async {
    if (reset) {
      offset = 0;
      hasMore = true;
      tasks.clear();
      isLoading = true;
      setState(() {});
    }

    if (!hasMore) return;

    isLoadingMore = true;

    try {
      final response = await http.post(
        Uri.parse('${baseUrl}all_task_list.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userId,
          'limit': limit,
          'offset': offset,
        }),
      );

      final data = jsonDecode(response.body);

      if (data['status'] == true) {
        List newTasks = data['data']['tasks'];

        setState(() {
          tasks.addAll(newTasks);
          offset += limit;
          hasMore = data['data']['has_more'];
        });
      }
    } catch (e) {
      debugPrint("Error loading all tasks: $e");
    }

    isLoading = false;
    isLoadingMore = false;
    setState(() {});
  }

  Future<void> _refresh() async {
    await _loadAllTasks(reset: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ==============================
  // DASHBOARD STYLE TASK TILE
  // ==============================

  Widget _taskTile(Map task) {
    final String title = task['title'] ?? '';
    final String priority = task['priority'] ?? 'NORMAL';
    final bool isOverdue = task['is_overdue'] == true;
    final String? dueDate = task['next_due_date'];
    final String? categoryName = task['category']?['category_name'];
    final int remarksCount = task['remarks_count'] ?? 0;

    final String? recurrenceType =
        task['recurrence_type']?.toString().toLowerCase();

    final bool isRecurring =
        recurrenceType != null &&
        recurrenceType.isNotEmpty &&
        recurrenceType != 'none';

    final int recurrenceInterval =
        int.tryParse(task['recurrence_interval']?.toString() ?? '1') ?? 1;

    final String? completedAt = task['completed_at'];
    final String? nextDueDate = task['next_due_date'];


    final bool isCompleted = task['completed_at'] != null;

    final Color statusColor = isOverdue
        ? Colors.red
        : priority == 'URGENT'
            ? Colors.orange
            : isRecurring
                ? _recurrenceColor(recurrenceType)
                : Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 46,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isRecurring)
                      Container(
                        margin: const EdgeInsets.only(left: 6, top: 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _recurrenceColor(recurrenceType)
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _recurrenceLabel(
                              recurrenceType, recurrenceInterval),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _recurrenceColor(recurrenceType),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if ((task['description'] ?? '')
                    .toString()
                    .isNotEmpty)
                  Text(
                    task['description'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (categoryName != null) ...[
                      Text(
                        categoryName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const Text(' • '),
                    ],
                    Text(
                      isCompleted
                          ? (nextDueDate != null && nextDueDate.toString().isNotEmpty
                              ? 'Completed ${formatDueDate(completedAt)} • Next ${formatDueDate(nextDueDate)}'
                              : 'Completed ${formatDueDate(completedAt)}')
                          : formatDueDate(dueDate),
                      style: TextStyle(
                        fontSize: 12,
                        color: isCompleted
                            ? Colors.green
                            : isOverdue
                                ? Colors.red
                                : isRecurring
                                    ? _recurrenceColor(recurrenceType)
                                    : Colors.grey.shade600,
                        fontWeight: isCompleted
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),                    
                    if (remarksCount > 0) ...[
                      const Text(' • '),
                      Text(
                        '$remarksCount',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==============================
  // HELPERS (Copied from Dashboard)
  // ==============================

  String formatDueDate(String? dateTime) {
    if (dateTime == null || dateTime.isEmpty) return 'No due date';

    final due = DateTime.parse(dateTime);
    final now = DateTime.now();
    final diff = due.difference(now);

    if (DateUtils.isSameDay(due, now)) {
      if (diff.inMinutes >= 0) {
        if (diff.inMinutes < 60) {
          return 'In ${diff.inMinutes} min';
        } else {
          final hrs = diff.inHours;
          return 'In $hrs hour${hrs > 1 ? 's' : ''}';
        }
      } else {
        final mins = diff.inMinutes.abs();
        if (mins < 60) {
          return 'Before $mins min';
        } else {
          final hrs = mins ~/ 60;
          return 'Before $hrs hour${hrs > 1 ? 's' : ''}';
        }
      }
    }

    if (DateUtils.isSameDay(due, now.add(const Duration(days: 1)))) {
      return 'Tomorrow';
    }

    if (DateUtils.isSameDay(due, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }

    if (diff.inDays > 0) {
      return 'After ${diff.inDays} day${diff.inDays > 1 ? 's' : ''}';
    }

    final pastDays = diff.inDays.abs();
    return 'Before $pastDays day${pastDays > 1 ? 's' : ''}';
  }

  Color _recurrenceColor(String? type) {
    switch (type) {
      case 'daily':
        return Colors.green;
      case 'weekly':
        return Colors.blue;
      case 'monthly':
        return Colors.purple;
      case 'yearly':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _recurrenceLabel(String? type, int interval) {
    if (type == null) return '';
    final upper = type.toUpperCase();
    if (interval <= 1) return upper;
    return '$upper ($interval)';
  }

  // ==============================
  // UI
  // ==============================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("All Tasks")),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : tasks.isEmpty
                ? const Center(child: Text("No tasks found"))
                : ListView.separated(
                    controller: _scrollController,
                    itemCount: tasks.length + (hasMore ? 1 : 0),
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, thickness: 0.6),
                    itemBuilder: (context, index) {
                      if (index < tasks.length) {
                        return _taskTile(tasks[index]);
                      } else {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                    },
                  ),
      ),
    );
  }
}

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
          'user_id': widget.userId, // ✅ using passed userId
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

  Color _statusColor(String status, String isDeleted) {
    if (isDeleted == "1") return Colors.red;
    if (status == "COMPLETED") return Colors.green;
    if (status == "IN_PROGRESS") return Colors.orange;
    return Colors.blue;
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTaskCard(Map task) {
    final status = task["status"] ?? "";
    final String isDeleted =
      task["is_deleted"]?.toString() ?? "0";

    final recurrence = task["recurrence_type"];

    final String? recurrenceType = task["recurrence_type"];
    final bool isRecurring =
        recurrenceType != null && recurrenceType.toString().isNotEmpty;

    final String? nextDue = task["next_due_date"];
    final String? completedAt = task["completed_at"];    

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task["title"] ?? "",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 6),

            if ((task["description"] ?? "").toString().isNotEmpty)
              Text(
                task["description"],
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),

            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildBadge(
                  status,
                  _statusColor(status, isDeleted),
                ),
                if (isDeleted == "1")
                  _buildBadge("DELETED", Colors.red),
                if (recurrence != null && recurrence != "")
                  _buildBadge("RECURRING", Colors.purple),
              ],
            ),

            const SizedBox(height: 10),

Text(
  "Created: ${task["created_at"] ?? ""}",
  style: const TextStyle(
    fontSize: 12,
    color: Colors.grey,
  ),
),

const SizedBox(height: 4),

if (status == "COMPLETED" && !isRecurring)
  Text(
    "Completed: ${completedAt ?? "-"}",
    style: const TextStyle(
      fontSize: 12,
      color: Colors.green,
      fontWeight: FontWeight.w600,
    ),
  )
else
  Text(
    "Next Due: ${nextDue ?? "-"}",
    style: const TextStyle(
      fontSize: 12,
      color: Colors.grey,
    ),
  ),            
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: tasks.length + (hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < tasks.length) {
                        return _buildTaskCard(tasks[index]);
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

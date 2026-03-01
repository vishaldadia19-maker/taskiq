import 'package:flutter/material.dart';
import '../services/single_task_service.dart';
import '../models/task_detail_model.dart';

class TaskDetailScreen extends StatefulWidget {
  final int taskId;
  final int userId;

  const TaskDetailScreen({
    super.key,
    required this.taskId,
    required this.userId,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late Future<TaskDetailModel> _future;

  @override
  void initState() {
    super.initState();
    _future = SingleTaskService.fetchTaskDetails(
      widget.taskId,
      widget.userId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text(
          "Task Details",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<TaskDetailModel>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Something went wrong",
                style: TextStyle(color: Colors.red.shade400),
              ),
            );
          }

          final data = snapshot.data!;
          final task = data.task;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _summaryCard(task),
                const SizedBox(height: 16),
                _descriptionCard(task),
                const SizedBox(height: 16),
                _infoCard(task),
                const SizedBox(height: 16),
                _participantsCard(data.participants),
                const SizedBox(height: 16),
                _milestonesCard(data.milestones),
                const SizedBox(height: 16),
                _completionCard(data.completionHistory),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  // ================= SUMMARY =================

  Widget _summaryCard(Map<String, dynamic> task) {
    return _cardWrapper(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task["title"] ?? "",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _badge(task["status"], Colors.blue),
              const SizedBox(width: 8),
              _badge(task["priority"], Colors.red),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Next Due: ${task["next_due_date"] ?? "-"}",
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // ================= DESCRIPTION =================

  Widget _descriptionCard(Map<String, dynamic> task) {
    if ((task["description"] ?? "").toString().isEmpty) {
      return const SizedBox();
    }

    return _cardWrapper(
      Text(
        task["description"],
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  // ================= INFO =================

  Widget _infoCard(Map<String, dynamic> task) {
    return _cardWrapper(
      Column(
        children: [
          _infoRow("Created By", task["created_by_name"] ?? "-"),
          _infoRow("Created At", task["created_at"] ?? "-"),
          _infoRow("Last Done", task["last_done_date"] ?? "-"),
          _infoRow("Recurrence", task["recurrence_type"] ?? "-"),
          _infoRow(
            "Show Daily",
            task["show_daily_until_done"] == "1" ? "Yes" : "No",
          ),
        ],
      ),
    );
  }

  // ================= PARTICIPANTS =================

  Widget _participantsCard(List participants) {
    if (participants.isEmpty) return const SizedBox();

    return _cardWrapper(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Participants",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          ...participants.map((p) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.purple.withOpacity(0.15),
                    child: Text(
                      (p["full_name"] ?? "")
                          .toString()
                          .substring(0, 1)
                          .toUpperCase(),
                      style: const TextStyle(
                          color: Colors.purple),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      p["full_name"] ?? "",
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    p["role"] ?? "",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  )
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // ================= MILESTONES =================

  Widget _milestonesCard(List milestones) {
    if (milestones.isEmpty) return const SizedBox();

    return _cardWrapper(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Milestones",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          ...milestones.map((m) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m["description"] ?? "",
                    style: const TextStyle(
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Created: ${m["created_at"] ?? "-"}",
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey),
                  ),
                  if (m["extended_date"] != null)
                    Text(
                      "Next FUP: ${m["extended_date"]}",
                      style: const TextStyle(
                          fontSize: 12, color: Colors.red),
                    ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // ================= COMPLETION =================

  Widget _completionCard(List history) {
    if (history.isEmpty) return const SizedBox();

    return _cardWrapper(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Completion History",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          ...history.map((h) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Completed by ${h["full_name"] ?? "-"}",
                    style: const TextStyle(
                        fontWeight: FontWeight.w500),
                  ),
                  Text(
                    h["completed_at"] ?? "-",
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // ================= REUSABLE =================

  Widget _cardWrapper(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String? text, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text ?? "",
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
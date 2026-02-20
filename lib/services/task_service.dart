import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';


class TaskService {
  static const String _baseUrl =
      'https://backoffice.thecubeclub.co/task_apis';

  // ================= CREATE TASK =================
  static Future<Map<String, dynamic>> createTask({
  required String title,
  required String description,
  required String taskType,
  required String priority,

  required String recurrenceType,
  String? recurrenceDays,

  required int? projectId,
  required List<int> assignees,
  required List<int> watchers,
  required String deadline,
  required int createdBy,
  required int? categoryId,
  required bool showDailyUntilDone,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/create_task.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "title": title,
        "description": description ?? "",
        "task_type": taskType,
        "priority": priority,
        "recurrence_type":
          recurrenceType == 'none' ? null : recurrenceType,
        "recurrence_days":
          recurrenceType == 'weekly' ? recurrenceDays : null,
        "project_id": projectId,
        "assignees": assignees,
        "watchers": watchers ?? [],
        "proposed_deadline": deadline,
        "created_by": createdBy,
        "category_id": categoryId,
        "show_daily_until_done": showDailyUntilDone ? 1 : 0, // 🔥

      }),
    );

    debugPrint('🟢 CREATE TASK RAW RESPONSE: ${response.body}');
    return jsonDecode(response.body);
  }


  // ================= UPDATE TASK =================
  static Future<Map<String, dynamic>> updateTask({
    required int taskId,
    required String title,
    String? description,
    required String priority,
    required String deadline,
    int? categoryId,
    required bool showDailyUntilDone,

    required String recurrenceType,
    String? recurrenceDays,

    // 🔥 ADD THESE
    required String taskType,
    required List<int> assignees,
    required List<int> watchers,
  }) async {
  

    debugPrint('Recur Type: $recurrenceType');
    debugPrint('recurrence_days: $recurrenceDays');


    final res = await http.post(
      Uri.parse('$_baseUrl/update_task.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'task_id': taskId,
        'title': title,
        'description': description ?? '',
        'priority': priority,
        'deadline': deadline,
        'category_id': categoryId,
        'show_daily_until_done': showDailyUntilDone ? 1 : 0,
        'recurrence_type':
            recurrenceType == 'none' ? null : recurrenceType,
        'recurrence_days':
            recurrenceType == 'weekly' ? recurrenceDays : null,

        // 🔥 ADD THESE
        'task_type': taskType,
        'assignees': assignees,
        'watchers': watchers,
      }),      
    );

    debugPrint('🟢 UPDATE TASK RAW RESPONSE: ${res.body}');

    return jsonDecode(res.body);
  }
}

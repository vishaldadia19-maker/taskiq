import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';


class TaskDeleteService {
  static const String _baseUrl =
      'https://backoffice.thecubeclub.co/task_apis';

  static Future<bool> deleteTask({
    required int taskId,
    required int userId,
  }) async {
    debugPrint('🗑 DELETE TASK → task_id=$taskId user_id=$userId');

    final res = await http.post(
      Uri.parse('$_baseUrl/delete_task.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'task_id': taskId,
        'user_id': userId,
      }),
    );

  debugPrint('🗑 DELETE RESPONSE STATUS: ${res.statusCode}');
  debugPrint('🗑 DELETE RESPONSE BODY: ${res.body}');    

    final data = jsonDecode(res.body);
    return data['success'] == true;
  }
}

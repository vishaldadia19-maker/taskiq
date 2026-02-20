import 'dart:convert';
import 'package:http/http.dart' as http;

class TaskCompleteService {
  static const String apiUrl =
      'https://backoffice.thecubeclub.co/task_apis/task_complete.php';

  static Future<bool> completeTask({
    required int userId,
    required int taskId,
  }) async {
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'task_id': taskId,
      }),
    );

    final data = jsonDecode(response.body);
    return data['status'] == true;
  }
}

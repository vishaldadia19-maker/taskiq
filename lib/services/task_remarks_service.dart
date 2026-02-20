import 'dart:convert';
import 'package:http/http.dart' as http;

class TaskRemarksService {
  static Future<List<Map<String, dynamic>>> fetchRemarks({
    required int taskId,
    required int userId,
  }) async {
    const String url =
        'https://backoffice.thecubeclub.co/task_apis/get_task_remarks.php';

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'task_id': taskId,
        'user_id': userId,
      }),
    );

    final decoded = jsonDecode(response.body);

    if (decoded['success'] == true) {
      return List<Map<String, dynamic>>.from(
        decoded['data']['remarks'],
      );
    }

    return [];
  }
}

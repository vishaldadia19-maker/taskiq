import 'dart:convert';
import 'package:http/http.dart' as http;

class TaskCompletedListService {
  static const String apiUrl =
      'https://backoffice.thecubeclub.co/task_apis/task_completed_list.php';

  static Future<Map<String, dynamic>> fetchCompletedTasks({
    required int userId,
    required int offset,
    int limit = 10,
  }) async {
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'limit': limit,
        'offset': offset,
      }),
    );

    return jsonDecode(response.body);
  }
}

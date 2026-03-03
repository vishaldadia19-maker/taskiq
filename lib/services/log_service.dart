import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class LogService {

  static Future<Map<String, dynamic>> createLog({
    required String title,
    required String description,
    required String taskType,
    required int createdBy,
    required int? categoryId,
    required String completionDate,
    required List<int> assignees,
    required List<int> watchers,
  }) async {
    final url = Uri.parse("${baseUrl}create_log.php");


    final body = {
      "title": title,
      "description": description,
      "task_type": taskType,
      "created_by": createdBy,
      "category_id": categoryId,
      "completion_date": completionDate,
      "assignees": assignees,
      "watchers": watchers,
    };

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    return jsonDecode(response.body);
  }
}
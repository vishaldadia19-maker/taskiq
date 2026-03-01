import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task_detail_model.dart';
import '../config/api_config.dart';

class SingleTaskService {

  static Future<TaskDetailModel> fetchTaskDetails(
      int taskId, int userId) async {

    final response = await http.post(
      Uri.parse("${baseUrl}get_task_details.php"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "task_id": taskId,
        "user_id": userId,
      }),
    );

    final data = jsonDecode(response.body);

    if (data['status'] == true) {
      return TaskDetailModel.fromJson(data);
    } else {
      throw Exception(data['message'] ?? "Failed to load task");
    }
  }
}
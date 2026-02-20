import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';


class TaskHandleTodayService {

  static Future<bool> handleToday({
    required int taskId,
    required int userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${baseUrl}task_snooze_today.php'),

        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'task_id': taskId,
          'user_id': userId,
        }),
      );

      if (response.statusCode != 200) {
        return false;
      }

      final data = jsonDecode(response.body);
      return data['status'] == true;
    } catch (e) {
      return false;
    }
  }
}

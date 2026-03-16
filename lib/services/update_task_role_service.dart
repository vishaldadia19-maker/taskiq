import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class UpdateTaskRoleService {

  static Future<Map<String, dynamic>> updateRole({
    required int taskId,
    required int userId,
    required String action, // DOER | VIEWER | REMOVE
  }) async {

    try {

      final response = await http.post(
        Uri.parse('${baseUrl}update_task_role.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'task_id': taskId,
          'user_id': userId,
          'action': action
        }),
      );

      return jsonDecode(response.body);

    } catch (e) {
      return {
        "success": false,
        "error": e.toString()
      };
    }
  }
}
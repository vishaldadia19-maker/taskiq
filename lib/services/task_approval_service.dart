import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class TaskApprovalService {
  static Future<Map<String, dynamic>> handleApproval({
    required int taskId,
    required int userId,
    required String action, // APPROVE or REJECT
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${baseUrl}task_approval.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'task_id': taskId,
          'user_id': userId,
          'action': action,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {
        "status": false,
        "message": "Something went wrong"
      };
    }
  }
}

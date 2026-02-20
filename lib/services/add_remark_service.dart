import 'dart:convert';
import 'package:http/http.dart' as http;

class AddRemarkService {
  static Future<Map<String, dynamic>> addRemark({
    required int taskId,
    required int userId,
    required String description,
    String? extendedDate, // ✅ NEW
  }) async {
    const String url = 'https://backoffice.thecubeclub.co/task_apis/add_task_remark.php';
    
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'task_id': taskId,
        'user_id': userId,
        'description': description,
        if (extendedDate != null) 'extended_date': extendedDate,
      }),
    );

    return jsonDecode(response.body);
  }
  
}




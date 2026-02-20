import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';



class TaskMarkIncompleteService {
  static Future<bool> markIncomplete({
    required int taskId,
    required int userId,
  }) async {
    try {

      

      final res = await http.post(
      Uri.parse('${baseUrl}mark_task_incomplete.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'task_id': taskId,
          'user_id': userId,
        }),
      );


      final data = jsonDecode(res.body);
      return data['success'] == true;
    } catch (e) {
      return false;
    }
  }
}

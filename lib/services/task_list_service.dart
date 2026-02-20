import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class TaskListService {
  static const String apiUrl =
      'https://backoffice.thecubeclub.co/task_apis/task_list.php';

  static Future<Map<String, dynamic>> fetchTasks({
    required int userId,
    required int offset,
    int limit = 20,
    String? search = '',
    String filter = 'ALL',
    List<int>? delegateIds,
    List<String>? priorities,
    List<int>? categoryIds, // ✅ ADD
    int? isDaily, // 🔥 ADD



  }) async {

    // 🔹 Build request body dynamically
    final Map<String, dynamic> body = {
      'user_id': userId,
      'limit': limit,
      'offset': offset,
      'search': search ?? '',
      'filter': filter,
      'show_daily_until_done': isDaily, // 🔥 ADD


    };

    // 🔹 ADD delegate filter if present
    if (delegateIds != null && delegateIds.isNotEmpty) {
      body['delegate_ids'] = delegateIds;
    }

    // 🔹 ADD priority filter if present
    if (priorities != null && priorities.isNotEmpty) {
      body['priorities'] = priorities;
    }

    if (categoryIds != null && categoryIds.isNotEmpty) {
      body['category_ids'] = categoryIds; // ✅ ADD
    }    

    //debugPrint('🟠 TASK LIST API PAYLOAD');


    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    //debugPrint('🟢 RAW API RESPONSE: ${response.body}');

    return jsonDecode(response.body);


  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DashboardService {
  static const String baseUrl =
      "https://backoffice.thecubeclub.co/task_apis/dashboard.php";

  static Future<Map<String, dynamic>> fetchDashboard() async {
    // 🔥 GET USER ID FROM STORAGE
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId == null) {
      throw Exception("User not logged in");
    }

    // 🔍 DEBUG (remove later)
    print("📤 Dashboard API user_id: $userId");

    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "user_id": userId,
      }),
    );

    if (response.statusCode == 200) {
      final body = json.decode(response.body);

      if (body['status'] == true) {
        return body['data'];
      } else {
        throw Exception(body['message']);
      }
    } else {
      throw Exception("Server error");
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;

class DelegateListService {
  static const String _url =
      'https://backoffice.thecubeclub.co/task_apis/delegate_list.php';

  static Future<List<Map<String, dynamic>>> fetchDelegates({
    required int userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded['status'] == true) {
          return List<Map<String, dynamic>>.from(
            decoded['data']['delegates'],
          );
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}

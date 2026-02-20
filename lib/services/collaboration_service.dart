import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class CollaborationService {

  static Future<Map<String, dynamic>> sendRequest({
    required int userId,
    required int targetUserId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${baseUrl}send_collab_request.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
          'target_user_id': targetUserId,
        }),
      );

      if (response.statusCode != 200) {
        return {"status": false, "message": "Server error"};
      }

      return jsonDecode(response.body);
    } catch (e) {
      return {"status": false, "message": "Exception occurred"};
    }
  }

  static Future<Map<String, dynamic>> approveCollaboration({
    required int userId,
    required int collaborationId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${baseUrl}approve_collab.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
          'collaboration_id': collaborationId,
        }),
      );

      if (response.statusCode != 200) {
        return {"status": false, "message": "Server error"};
      }

      return jsonDecode(response.body);
    } catch (e) {
      return {"status": false, "message": "Exception occurred"};
    }
  }

  static Future<Map<String, dynamic>> rejectRequest({
    required int userId,
    required int collaborationId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${baseUrl}reject_collab.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'collaboration_id': collaborationId,
        }),
      );

      if (response.statusCode != 200) {
        return {"status": false, "message": "Server error"};
      }

      return jsonDecode(response.body);
    } catch (e) {
      return {"status": false, "message": "Exception occurred"};
    }
  }
  

}

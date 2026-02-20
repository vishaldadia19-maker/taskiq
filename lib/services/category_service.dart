import 'dart:convert';
import 'package:http/http.dart' as http;

class CategoryService {
  static Future<Map<String, dynamic>> createCategory({
    required int userId,
    required String name,
  }) async {
    final res = await http.post(
      Uri.parse(
        'https://backoffice.thecubeclub.co/task_apis/create_category.php',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'category_name': name,
      }),
    );

    return jsonDecode(res.body);
  }

  static Future<List<Map<String, dynamic>>> fetchCategories({
    required int userId,
  }) async {
    final res = await http.post(
      Uri.parse(
        'https://backoffice.thecubeclub.co/task_apis/get_categories.php',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
      }),
    );

    final data = jsonDecode(res.body);

    if (data['success'] == true && data['categories'] is List) {
      return List<Map<String, dynamic>>.from(data['categories']);
    }

    return [];
  }

  static Future<Map<String, dynamic>> deleteCategory({
    required int categoryId,
  }) async {
    final res = await http.post(
      Uri.parse(
        'https://backoffice.thecubeclub.co/task_apis/delete_category.php',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'category_id': categoryId,
      }),
    );

    return jsonDecode(res.body);
  }
  

  // ✅ FIXED IMPLEMENTATION
  static Future<Map<String, dynamic>> updateCategory({
    required int categoryId,
    required String name,
  }) async {
    final res = await http.post(
      Uri.parse(
        'https://backoffice.thecubeclub.co/task_apis/update_category.php',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'category_id': categoryId,
        'category_name': name,
      }),
    );

    return jsonDecode(res.body);
  }
}

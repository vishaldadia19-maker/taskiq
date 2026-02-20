import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'create_category.dart';
import '../services/category_service.dart';


class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  bool loading = false;
  int? userId;

  List<Map<String, dynamic>> categories = [];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getInt('user_id');

    if (userId != null) {
      _loadCategories();
    }
  }

  Future<void> _loadCategories() async {
    setState(() => loading = true);

    try {
      final res = await http.post(
        Uri.parse(
          'https://backoffice.thecubeclub.co/task_apis/get_categories.php',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      );

      final data = jsonDecode(res.body);

      if (data['success'] == true) {
        categories =
            List<Map<String, dynamic>>.from(data['categories']);
      }
    } catch (e) {
      debugPrint('Category load error: $e');
    }

    setState(() => loading = false);
  }

  void _editCategory(Map<String, dynamic> category) async {

  debugPrint('🟡 EDIT CLICKED');
  debugPrint('🟡 Category data: $category');

    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateCategoryScreen(
          isEdit: true,
          category: category,
        ),
      ),
    );

  debugPrint('🟡 Returned from edit screen: $updated');


    if (updated == true) {
      _loadCategories();      
    }
  }
  

void _deleteCategory(Map<String, dynamic> category) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Delete Category'),
      content: const Text(
        'This category will be deleted permanently.\n\nAre you sure?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () async {
            Navigator.pop(context);

            final res = await CategoryService.deleteCategory(
              categoryId: category['id'],
            );

            if (res['success'] == true) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Category deleted')),
              );
              _loadCategories();
              Navigator.pop(context, true); // notify CreateTaskScreen
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    res['error'] ?? 'Unable to delete category',
                  ),
                ),
              );
            }
          },
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manage Categories',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create Category',
            onPressed: () async {
              final created = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateCategoryScreen(),
                ),
              );

              if (created == true) {
                _loadCategories();
                //Navigator.pop(context, true);
              }
            },
          )
        ],
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : categories.isEmpty
              ? _emptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: categories.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final c = categories[index];

                    // for now assume deletable
                    final bool canDelete = true;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              c['category_name'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _editCategory(c),
                          ),

                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: canDelete
                                  ? Colors.red
                                  : Colors.grey,
                            ),
                            onPressed:
                                canDelete ? () => _deleteCategory(c) : null,
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.category_outlined,
              size: 60, color: Colors.grey),
          const SizedBox(height: 12),
          const Text(
            'No categories yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create categories to organize your tasks',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              final created = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateCategoryScreen(),
                ),
              );

              if (created == true) {
                _loadCategories();
              }
            },
            child: const Text('Create Category'),
          )
        ],
      ),
    );
  }
}

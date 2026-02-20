import 'package:flutter/material.dart';
import '../services/category_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreateCategoryScreen extends StatefulWidget {
  final bool isEdit;
  final Map<String, dynamic>? category;

  const CreateCategoryScreen({
    super.key,
    this.isEdit = false,
    this.category,
  });

  @override
  State<CreateCategoryScreen> createState() => _CreateCategoryScreenState();
}

class _CreateCategoryScreenState extends State<CreateCategoryScreen> {
  final _nameCtrl = TextEditingController();
  bool loading = false;

  @override
  void initState() {
    super.initState();

    // ✅ Prefill name when editing
    if (widget.isEdit && widget.category != null) {
      _nameCtrl.text = widget.category!['category_name'] ?? '';
    }
  }

  Future<void> _submit() async {

 debugPrint('🔵 SUBMIT CLICKED');
  debugPrint('🔵 isEdit = ${widget.isEdit}');
  debugPrint('🔵 name = ${_nameCtrl.text}');
  debugPrint('🔵 category id = ${widget.category?['id']}');  

  
    if (_nameCtrl.text.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    setState(() => loading = true);

    Map<String, dynamic> res;

    if (widget.isEdit) {
      // 🔁 UPDATE CATEGORY
      res = await CategoryService.updateCategory(
        categoryId: widget.category!['id'],
        name: _nameCtrl.text.trim(),
      );
    } else {
      // ➕ CREATE CATEGORY
      res = await CategoryService.createCategory(
        userId: userId,
        name: _nameCtrl.text.trim(),
      );
    }

    setState(() => loading = false);

    if (res['success'] == true) {
      Navigator.pop(context, true); // notify previous screen
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error'] ?? 'Failed')),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEdit ? 'Edit Category' : 'Create Category',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Category name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: loading ? null : _submit,
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        widget.isEdit ? 'Update Category' : 'Save Category',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

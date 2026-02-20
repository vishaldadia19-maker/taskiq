import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/collaboration_service.dart';


class SearchParticipantScreen extends StatefulWidget {

  final int userId;

 const SearchParticipantScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);  

@override
  State<SearchParticipantScreen> createState() =>
      _SearchParticipantScreenState();


}

class _SearchParticipantScreenState extends State<SearchParticipantScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  bool _isLoading = false;
  List<dynamic> _users = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchUsers(value);
    });
  }

Future<void> _searchUsers(String query) async {
  if (query.isEmpty) {
    setState(() => _users = []);
    return;
  }

  setState(() => _isLoading = true);

  try {
    final response = await http.post(
      
      Uri.parse('${baseUrl}search_participants.php'),

      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "user_id": widget.userId,
        "query": query,
      }),
    );

    final data = jsonDecode(response.body);

    if (data["status"] == true) {
      setState(() {
        _users = data["data"];
      });
    } else {
      setState(() => _users = []);
    }
  } catch (e) {
    setState(() => _users = []);
  }

  setState(() => _isLoading = false);
}


Future<void> _sendRequest(int targetUserId) async {
  final response = await CollaborationService.sendRequest(
    userId: widget.userId,
    targetUserId: targetUserId,
  );

  if (response["status"] == true) {

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(response["message"] ?? "Request sent")),
    );

    // 🔥 Remove user from search list immediately
    setState(() {
      _users.removeWhere((u) => u["id"] == targetUserId);
    });

  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(response["message"] ?? "Failed")),
    );
  }
}
  

  

  Widget _buildUserTile(Map user) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.person_outline),
        ),
        title: Text(user['name']),
        subtitle: Text(user['email']),
        trailing: ElevatedButton(
          onPressed: () => _sendRequest(user['id']),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: const Text("Connect"),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Participant"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: "Search by name or email",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator()),
            if (!_isLoading && _users.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    "Search users to connect",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            if (!_isLoading && _users.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (context, index) =>
                      _buildUserTile(_users[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

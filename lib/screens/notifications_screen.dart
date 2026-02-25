import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState
    extends State<NotificationsScreen> {

  List notifications = [];
  bool isLoading = true;
  int? userId;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getInt('user_id');

    final response = await http.post(
      Uri.parse('${baseUrl}get_notifications.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
      }),
    );

    final data = jsonDecode(response.body);

    if (data['status'] == true) {
      setState(() {
        notifications = data['notifications'];
        isLoading = false;
      });

      // Mark all as read automatically
      await _markAllRead();
    }
  }

  Future<void> _markAllRead() async {
    await http.post(
      Uri.parse('${baseUrl}mark_notification_read.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'mark_all': true,
      }),
    );
  }

  @override
  Widget build(BuildContext context) {


    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? const Center(
                  child: Text('No notifications'),
                )
              : ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final n = notifications[index];

                    final String? triggeredBy = n['triggered_name'];
                    String subtitleText;

                    if (n['type'] == 'invitation_accept' && triggeredBy != null) {
                      subtitleText =
                          "$triggeredBy accepted your collaboration request.";
                    } else if (n['type'] == 'invitation_reject' &&
                        triggeredBy != null) {
                      subtitleText =
                          "$triggeredBy rejected your collaboration request.";
                    } else {
                      subtitleText = n['message'] ?? '';
                    }

                    return ListTile(
                      title: Text(
                        n['title'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(subtitleText),
                      trailing: Text(
                        n['created_at'] ?? '',
                        style: const TextStyle(fontSize: 11),
                      ),
                    );
                  },                  
                ),
    );
  }
}
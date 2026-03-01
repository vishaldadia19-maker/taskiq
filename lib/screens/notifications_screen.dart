import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_screen.dart'; // adjust path if needed
import 'participants_screen.dart';
import 'task_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {

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

      await _markAllRead();
    } else {
      setState(() {
        isLoading = false;
      });
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

  Future<bool> _handleBack() async {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
      (route) => false,
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {

    return WillPopScope(
      onWillPop: _handleBack,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6F8),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: _handleBack,
          ),
          title: const Text(
            'Notifications',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : notifications.isEmpty
                ? const Center(
                    child: Text(
                      'No notifications',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final n = notifications[index];

                      final String? triggeredBy = n['triggered_name'];
                      String subtitleText;

                      if (n['type'] == 'invitation_accept' &&
                          triggeredBy != null) {
                        subtitleText =
                            "$triggeredBy accepted your collaboration request.";
                      } else if (n['type'] == 'invitation_reject' &&
                          triggeredBy != null) {
                        subtitleText =
                            "$triggeredBy rejected your collaboration request.";
                      } else {
                        subtitleText = n['message'] ?? '';
                      }
                        return InkWell(
                          onTap: () {
                          
                            print("CLICKED NOTIFICATION");
                            print(n);

                              if (n['type'] == 'invitation_accept' ||
                                  n['type'] == 'invitation_reject') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ParticipantsScreen(userId: userId!),
                                ),
                              );
                            }
                             // Task Assigned → Task Detail
                              else if (n['type'] == 'TASK_ASSIGNED') {
                                final int taskId = n['reference_id'];

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TaskDetailScreen(
                                      taskId: taskId,
                                      userId: userId!,
                                    ),
                                  ),
                                );
                              }                            
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 4,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        n['title'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        subtitleText,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        n['created_at'] ?? '',
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );                      
                    },
                  ),
      ),
    );
  }
}

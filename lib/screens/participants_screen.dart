import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'search_participant_screen.dart';
import '../services/collaboration_service.dart';

class ParticipantsScreen extends StatefulWidget {
  final int userId;

  const ParticipantsScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<ParticipantsScreen> createState() => _ParticipantsScreenState();
}

class _ParticipantsScreenState extends State<ParticipantsScreen> {
  List collaborations = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCollaborations();
  }

  Future<void> _loadCollaborations() async {
    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${baseUrl}get_collaborations.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userId,
        }),
      );

      final data = jsonDecode(response.body);

      if (data['status'] == true) {
        setState(() {
          collaborations = data['data'];
        });
      }
    } catch (e) {
      debugPrint("Error loading collaborations: $e");
    }

    setState(() => isLoading = false);
  }

  Color _statusColor(String status, int requestedBy) {
    if (status == 'APPROVED') return Colors.green;
    if (requestedBy == widget.userId) return Colors.orange;
    return Colors.blue;
  }

  String _statusLabel(String status, int requestedBy) {
    if (status == 'APPROVED') return "Approved";
    if (requestedBy == widget.userId) return "Pending";
    return "Requested You";
  }

Widget _buildTile(Map item) {
  final status = item['status'];
  final requestedBy = item['requested_by'];

  final isApproved = status == 'APPROVED';
  final isPending = status == 'PENDING' && requestedBy == widget.userId;
  final isIncoming = status == 'PENDING' && requestedBy != widget.userId;

  return Container(
    margin: const EdgeInsets.symmetric(vertical: 4),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        /// SMALLER AVATAR
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: item['profile_photo'] != null &&
                  item['profile_photo'].toString().isNotEmpty
              ? NetworkImage(item['profile_photo'])
              : null,
          child: item['profile_photo'] == null ||
                  item['profile_photo'].toString().isEmpty
              ? Text(
                  item['name'][0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : null,
        ),

        const SizedBox(width: 10),

        /// NAME + EMAIL + STATUS
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Row(
                children: [
                  Expanded(
                    child: Text(
                      item['name'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _statusDot(status, requestedBy),
                ],
              ),

              const SizedBox(height: 2),

              Text(
                item['email'],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        /// ACTION BUTTON
        _compactAction(item, isApproved, isPending, isIncoming),
      ],
    ),
  );
}

Widget _statusDot(String status, int requestedBy) {
  Color color;
  String label;

  if (status == 'APPROVED') {
    color = Colors.green;
    label = "Approved";
  } else if (requestedBy == widget.userId) {
    color = Colors.orange;
    label = "Pending";
  } else {
    color = Colors.blue;
    label = "Incoming";
  }

  return Row(
    children: [
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 4),
      Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

Widget _compactAction(
  Map item,
  bool isApproved,
  bool isPending,
  bool isIncoming,
) {
  if (isApproved) {
    return GestureDetector(
      onTap: () {
        // remove
      },
      child: const Text(
        "Remove",
        style: TextStyle(
          fontSize: 12,
          color: Colors.red,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  if (isPending) {
    return GestureDetector(
      onTap: () {
        // cancel
      },
      child: const Text(
        "Cancel",
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey,
        ),
      ),
    );
  }

  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      GestureDetector(
        onTap: () {
          // reject
        },
        child: const Text(
          "Reject",
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: () {
          // approve
        },
        child: const Text(
          "Approve",
          style: TextStyle(
            fontSize: 12,
            color: Colors.green,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}



Widget _buildBetterActions(
  Map item,
  bool isApproved,
  bool isPending,
  bool isIncoming,
) {
  if (isApproved) {
    return TextButton(
      onPressed: () {
        // remove api
      },
      child: const Text(
        "Remove",
        style: TextStyle(color: Colors.red),
      ),
    );
  }

  if (isPending) {
    return TextButton(
      onPressed: () {
        // cancel api
      },
      child: const Text("Cancel"),
    );
  }

  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      TextButton(
        onPressed: () {
          // reject api
        },
        child: const Text("Reject"),
      ),
      const SizedBox(width: 6),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        onPressed: () {
          // approve api
        },
        child: const Text(
          "Approve",
          style: TextStyle(fontSize: 12),
        ),
      ),
    ],
  );
}


Widget _statusBadge(String status, int requestedBy) {
  Color color;
  String label;

  if (status == 'APPROVED') {
    color = Colors.green;
    label = "Approved";
  } else if (requestedBy == widget.userId) {
    color = Colors.orange;
    label = "Pending";
  } else {
    color = Colors.blue;
    label = "Requested You";
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    ),
  );
}
  

  Widget _buildActions(Map item) {
    final status = item['status'];
    final requestedBy = item['requested_by'];

    if (status == 'APPROVED') {
      return TextButton(
        onPressed: () {
          // TODO: Remove collaborator API
        },
        child: const Text("Remove"),
      );
    }

    if (status == 'PENDING' && requestedBy == widget.userId) {
      return TextButton(
        onPressed: () {
          // TODO: Cancel request API
        },
        child: const Text("Cancel"),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [

        TextButton(
          onPressed: () async {
            final res = await CollaborationService.rejectRequest(
              userId: widget.userId,
              collaborationId: item['collaboration_id'],
            );

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(res['message'] ?? 'Updated')),
            );

            if (res['status'] == true) {
              _loadCollaborations(); // refresh list
            }
          },
          child: const Text("Reject"),
        ),

        
        ElevatedButton(
          onPressed: () async {
            final response = await CollaborationService.approveCollaboration(
              userId: widget.userId,
              collaborationId: item['collaboration_id'],
            );

            if (response["status"] == true) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(response["message"])),
              );

              _loadCollaborations(); // refresh list
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(response["message"] ?? "Failed")),
              );
            }
          },
          child: const Text("Approve"),
        ),
        
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Participants"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : collaborations.isEmpty
              ? const Center(
                  child: Text(
                    "No collaborators yet.",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadCollaborations,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: collaborations.length,
                    itemBuilder: (context, index) =>
                        _buildTile(collaborations[index]),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  SearchParticipantScreen(userId: widget.userId),
            ),
          );

          _loadCollaborations(); // refresh after coming back
        },
        child: const Icon(Icons.person_add_alt_1),
      ),
    );
  }
}

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

    if (mounted) {
      setState(() => isLoading = false);
    }
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
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        )
      ],
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

        SizedBox(
          width: 110, // give fixed safe width
          child: Align(
            alignment: Alignment.centerRight,
            child: _compactAction(
              item,
              isApproved,
              isPending,
              isIncoming,
            ),
          ),
        ),        
      ],
    ),
  );
}

Widget _statusDot(String status, int requestedBy) {
  Color color;
  String label;

  if (status == 'APPROVED') {
    color = Colors.green.shade600;
    label = "Approved";
  } else if (requestedBy == widget.userId) {
    color = Colors.orange.shade600;
    label = "Pending";
  } else {
    color = Colors.blue.shade600;
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
  Future<void> _handleDelete() async {
    final res = await CollaborationService.rejectRequest(
      userId: widget.userId,
      collaborationId: item['collaboration_id'],
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(res['message'] ?? 'Updated')),
    );

    if (res['status'] == true) {
      _loadCollaborations();
    }
  }

  // APPROVED → Remove
  if (isApproved) {
    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: _handleDelete,
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

  // PENDING (you sent) → Cancel
  if (isPending) {
    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: _handleDelete,
      child: const Text(
        "Cancel",
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey,
        ),
      ),
    );
  }

  // PENDING (incoming) → Reject / Approve
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: _handleDelete,
        child: const Text(
          "Reject",
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ),
      const SizedBox(width: 6),
      TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () async {
          final response =
              await CollaborationService.approveCollaboration(
            userId: widget.userId,
            collaborationId: item['collaboration_id'],
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['message'] ?? 'Updated')),
          );

          if (response['status'] == true) {
            _loadCollaborations();
          }
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






  

Widget _benefit(String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle,
          size: 18,
          color: Colors.green,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildEmptyState() {
  return SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Icon(
            Icons.groups_rounded,
            size: 70,
            color: Colors.grey.shade300,
          ),

          const SizedBox(height: 20),

          const Text(
            "Work With Others",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            "Add people you work with.\n"
            "Share tasks and stay updated on progress.",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 20),

          _benefit("Share tasks with your team"),
          _benefit("See progress in real time"),
          _benefit("Stay aligned on work"),

          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      SearchParticipantScreen(userId: widget.userId),
                ),
              );

              _loadCollaborations();
            },
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text("Add Person"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),            
          ),

          const SizedBox(height: 12),

          Text(
            "Tip: The person will receive a request to join.",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    ),
  );
}



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Participants"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),      
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : collaborations.isEmpty
              ? _buildEmptyState()
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
        backgroundColor: Colors.green,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SearchParticipantScreen(userId: widget.userId),
            ),
          );
          _loadCollaborations();
        },
        child: const Icon(
          Icons.person_add_alt_1,
          color: Colors.white,
        ),
      ),      
    );
  }
}

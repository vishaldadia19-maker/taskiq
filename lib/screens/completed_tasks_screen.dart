import 'package:flutter/material.dart';
import '../services/task_completed_list_service.dart';
import '../services/task_mark_incomplete_service.dart';
import '../services/task_delete_service.dart';
import 'package:intl/intl.dart';
import '../services/task_remarks_service.dart';
import 'create_task_screen.dart';
import '../services/category_service.dart';

class CompletedTasksScreen extends StatefulWidget {
  final int userId;

  const CompletedTasksScreen({
    super.key,
    required this.userId,
  });

  @override
  State<CompletedTasksScreen> createState() => _CompletedTasksScreenState();
}

class _CompletedTasksScreenState extends State<CompletedTasksScreen> {

  final ScrollController _scrollController = ScrollController();

  List tasks = [];
  bool isLoading = false;
  bool hasMore = true;
  int offset = 0;

  DateTime? filterFromDate;
  DateTime? filterToDate;
  int? filterCategoryId;

  DateTime? selectedFromDate;
  DateTime? selectedToDate;
  int? selectedCategory;  

  List<Map<String, dynamic>> categories = [];  


  @override
  void initState() {
    super.initState();

    _loadCompletedTasks(reset: true);
    _loadCategories();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !isLoading &&
          hasMore) {
        _loadCompletedTasks();
      }
    });
  }

 Future<void> _loadCompletedTasks({bool reset = false}) async {
  if (isLoading) return;

  if (reset) {
    offset = 0;
    tasks.clear();
    hasMore = true;
  }

  setState(() => isLoading = true);

  final result = await TaskCompletedListService.fetchCompletedTasks(
    userId: widget.userId,
    offset: offset,
    fromDate: filterFromDate != null
        ? DateFormat('yyyy-MM-dd').format(filterFromDate!)
        : null,
    toDate: filterToDate != null
        ? DateFormat('yyyy-MM-dd').format(filterToDate!)
        : null,
    categoryId: filterCategoryId,
  );  

  if (result['status'] == true) {
    final List newTasks = result['data']['tasks'];

    setState(() {
      tasks.addAll(newTasks);
      offset = result['data']['next_offset'];
      hasMore = result['data']['has_more'];
    });
  }

  setState(() => isLoading = false);
}



  Future<void> _markTaskIncomplete(Map task) async {
    final success = await TaskMarkIncompleteService.markIncomplete(
      taskId: task['task_id'],
      userId: widget.userId,
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task moved back to pending')),
      );

      await _loadCompletedTasks(reset: true);
    }
  }

void _openRemarksSheet(Map task) async {
  List<Map<String, dynamic>> remarks = [];
  bool isLoading = true;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          if (isLoading) {
            TaskRemarksService.fetchRemarks(
              taskId: task['task_id'],
              userId: widget.userId,
            ).then((data) {
              setModalState(() {
                remarks = data;
                isLoading = false;
              });
            });
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                /// DRAG HANDLE
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(height: 12),

                /// HEADER
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Remarks',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),

                const Divider(),

                /// BODY
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  )
                else if (remarks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No remarks yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: remarks.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final r = remarks[index];
                        final addedBy = r['added_by']['name'];
                        final extended = r['extended_date'];

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              /// USER
                              Text(
                                addedBy,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),

                              const SizedBox(height: 6),

                              /// REMARK
                              Text(
                                r['description'],
                                style: const TextStyle(fontSize: 13),
                              ),

                              const SizedBox(height: 8),

                              /// META
                              Row(
                                children: [
                                  Text(
                                    formatExtendedDate(r['created_at']),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (extended != null && extended.toString().isNotEmpty)
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.schedule,
                                          size: 14,
                                          color: Colors.orange,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Extended to ${formatExtendedDate(extended)}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.orange,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),                                  
                                    
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      );
    },
  );
}



  Future<void> _deleteTask(Map task) async {
    final success = await TaskDeleteService.deleteTask(
      taskId: task['task_id'],
      userId: widget.userId,
    );

    if (success) {
      setState(() {
        tasks.removeWhere((t) => t['task_id'] == task['task_id']);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task deleted')),
      );
    }
  }

Future<void> _loadCategories() async {

  final data = await CategoryService.fetchCategories(
    userId: widget.userId,
  );

  setState(() {
    categories = data;
  });

}


void _openFilterSheet() {

  selectedFromDate = filterFromDate;
  selectedToDate = filterToDate;
  selectedCategory = filterCategoryId;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {

      return StatefulBuilder(
        builder: (context, setModalState) {

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                /// DRAG HANDLE
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                /// HEADER
                const Center(
                  child: Text(
                    "Filter Tasks",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                /// FROM DATE
                const Text(
                  "From Date",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 6),

                InkWell(
                  onTap: () async {

                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedFromDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );

                    if (picked != null) {
                      setModalState(() {
                        selectedFromDate = picked;
                      });
                    }

                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            selectedFromDate == null
                                ? "Select date"
                                : DateFormat('dd MMM yyyy')
                                    .format(selectedFromDate!),
                          ),
                        ),
                        const Icon(Icons.calendar_today, size: 18)
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                /// TO DATE
                const Text(
                  "To Date",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 6),

                InkWell(
                  onTap: () async {

                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedToDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );

                    if (picked != null) {
                      setModalState(() {
                        selectedToDate = picked;
                      });
                    }

                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            selectedToDate == null
                                ? "Select date"
                                : DateFormat('dd MMM yyyy')
                                    .format(selectedToDate!),
                          ),
                        ),
                        const Icon(Icons.calendar_today, size: 18)
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                /// CATEGORY
                DropdownButtonFormField<int>(
                  value: selectedCategory,
                  decoration: InputDecoration(
                    labelText: "Category",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: categories.map<DropdownMenuItem<int>>((cat) {
                    return DropdownMenuItem<int>(
                      value: cat['id'],
                      child: Text(cat['category_name']),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setModalState(() {
                      selectedCategory = val;
                    });
                  },
                ),

                const SizedBox(height: 22),

                /// BUTTONS
                Row(
                  children: [

                    /// CLEAR
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {

                          setState(() {
                            filterFromDate = null;
                            filterToDate = null;
                            filterCategoryId = null;
                          });

                          Navigator.pop(context);

                          _loadCompletedTasks(reset: true);

                        },
                        child: const Text("Clear"),
                      ),
                    ),

                    const SizedBox(width: 12),

                    /// APPLY
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {

                          setState(() {
                            filterFromDate = selectedFromDate;
                            filterToDate = selectedToDate;
                            filterCategoryId = selectedCategory;
                          });

                          Navigator.pop(context);

                          _loadCompletedTasks(reset: true);

                        },
                        child: const Text("Apply Filter"),
                      ),
                    ),
                  ],
                ),

              ],
            ),
          );

        },
      );

    },
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),

        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, true); // refresh dashboard
          },
        ),

        title: const Text(
          "Completed Tasks",
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
            IconButton(
              icon: const Icon(Icons.filter_alt),
              onPressed: _openFilterSheet,
            )
          ],        
      ),      

      body: RefreshIndicator(
        onRefresh: () async {
          await _loadCompletedTasks(reset: true);
        },
        child: ListView.separated(
          controller: _scrollController,
          itemCount: tasks.length + 1,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, thickness: 0.6),
          itemBuilder: (context, index) {

if (index < tasks.length) {

  final task = tasks[index];
  final group = getTaskGroup(task['completed_at']);

  String? previousGroup;

  if (index > 0) {
    previousGroup =
        getTaskGroup(tasks[index - 1]['completed_at']);
  }

  final showHeader = index == 0 || group != previousGroup;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      if (showHeader)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
          child: Text(
            group,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ),

      _taskTile(task),

      const Divider(height: 1, thickness: 0.6),
    ],
  );
}            

            if (hasMore) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            return const SizedBox(height: 80);
          },
        ),
      ),
    );
  }


Widget _taskTile(Map task) {

  final String title = task['title'] ?? '';
  final String priority = task['priority'] ?? 'NORMAL';
  final bool isOverdue = task['is_overdue'] == true;
  final String? dueDate = task['due_date'];
  final String? categoryName = task['category']?['category_name'];
  final int remarksCount = task['remarks_count'] ?? 0;

  final String workType = task['work_type'] ?? 'TASK';
  final bool isLog = workType == 'LOG';  

  final String? recurrenceType =
      task['recurrence_type']?.toString().toLowerCase();

  final bool isRecurring =
      recurrenceType != null &&
      recurrenceType.isNotEmpty &&
      recurrenceType != 'none';

  final completedByName = task['creator']?['name'];

  final int? creatorId = task['creator']?['user_id'];
  final int? completedById = task['completed_by']?['user_id'];  

  final bool canModify =
      widget.userId == creatorId || widget.userId == completedById;

  final int recurrenceInterval =
      int.tryParse(task['recurrence_interval']?.toString() ?? '1') ?? 1;

  final bool isCompleted = task['completed_at'] != null;

  final String? nextDueDate =
      task['next_due_date'] ?? task['due_date'];

  final Map<String, dynamic> participants =
      task['participants'] ?? {};

  final List doers =
      List<Map<String, dynamic>>.from(participants['doers'] ?? []);

  final List viewers =
      List<Map<String, dynamic>>.from(participants['viewers'] ?? []);

  final Color statusColor = isOverdue
      ? Colors.red
      : priority == 'URGENT'
          ? Colors.orange
          : isRecurring
              ? _recurrenceColor(recurrenceType)
              : Colors.green;

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        /// LEFT STATUS BAR
        Container(
          width: 3,
          height: 46,
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        const SizedBox(width: 10),

        /// MAIN CONTENT
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              /// TITLE
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              if (isLog)
                Container(
                  margin: const EdgeInsets.only(right: 6, top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    "LOG",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                ),              

                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  if (isRecurring)
                    Container(
                      margin: const EdgeInsets.only(left: 6, top: 2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _recurrenceColor(recurrenceType)
                            .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _recurrenceLabel(
                            recurrenceType, recurrenceInterval),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _recurrenceColor(recurrenceType),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 4),

              /// DESCRIPTION
              if ((task['description'] ?? '').toString().isNotEmpty)
                Text(
                  task['description'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),

              const SizedBox(height: 4),

              /// META LINE
              Row(
                children: [

                  Text(
                    priority,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          priority == 'URGENT'
                              ? FontWeight.w600
                              : FontWeight.normal,
                      color: priority == 'URGENT'
                          ? Colors.red
                          : Colors.grey.shade700,
                    ),
                  ),

                  const Text(' • '),

                  if (categoryName != null) ...[
                      Text(
                        categoryName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),                  
                    const Text(' • '),
                  ],

                  Expanded(
                    child: Text(
                      nextDueDate != null
                          ? '✓ $completedByName • ${formatExtendedDate(task['completed_at'])} • Next ${formatDueDate(nextDueDate)}'
                          : '✓ $completedByName • ${formatExtendedDate(task['completed_at'])}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                      ),
                    ),
                  ),              
                ],
              ),

              /// PARTICIPANTS
              if (doers.isNotEmpty || viewers.isNotEmpty) ...[
                const SizedBox(height: 6),
                _participantRow(doers, viewers),
              ],
            ],
          ),
        ),

        /// REMARK ICON
        if (remarksCount > 0)
          InkWell(
            onTap: () => _openRemarksSheet(task),
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    remarksCount.toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),        
          

        /// MENU
        if (canModify)
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 18),

          onSelected: (value) async {

            if (value == 'incomplete') {
              _markTaskIncomplete(task);
            }

            if (value == 'delete') {
              _deleteTask(task);
            }

          if (value == 'edit') {

            final updated = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateTaskScreen(
                  isEdit: true,
                  task: Map<String, dynamic>.from(task),
                ),
              ),
            );

            if (updated == true) {
              await _loadCompletedTasks(reset: true);
            }
          }


          },


          itemBuilder: (context) {

            if (isLog) {
              return [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit Log'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete'),
                ),
              ];
            }

            return [
              const PopupMenuItem(
                value: 'incomplete',
                child: Text('Mark as Incomplete'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete'),
              ),
            ];
          },          
        ),
      ],
    ),
  );
}
}

String getTaskGroup(String date) {
  final completed = DateTime.parse(date).toLocal();
  final now = DateTime.now();

  if (DateUtils.isSameDay(completed, now)) {
    return "Today";
  }

  if (DateUtils.isSameDay(
      completed, now.subtract(const Duration(days: 1)))) {
    return "Yesterday";
  }

  return "Older";
}

Color _recurrenceColor(String? type) {
  switch (type) {
    case 'daily':
      return Colors.green;
    case 'weekly':
      return Colors.blue;
    case 'monthly':
      return Colors.purple;
    case 'yearly':
      return Colors.orange;
    default:
      return Colors.grey;
  }
}

String _recurrenceLabel(String? type, int interval) {
  if (type == null) return '';

  final upper = type.toUpperCase();

  if (interval <= 1) return upper;

  return '$upper ($interval)';
}


String formatExtendedDate(String date) {
  final dt = DateTime.parse(date).toLocal();
  return DateFormat('dd-MMM-yy h:mm a').format(dt);
}


String formatDueDate(String? dateTime) {
  if (dateTime == null || dateTime.isEmpty) return 'No due date';

  final due = DateTime.parse(dateTime.replaceFirst(' ', 'T')).toLocal();
  final now = DateTime.now();

  final diff = due.difference(now);

  // TODAY
  if (DateUtils.isSameDay(due, now)) {
    if (diff.inMinutes >= 0) {
      // Future today
      if (diff.inMinutes < 60) {
        return 'In ${diff.inMinutes} min';
      } else {
        final hrs = diff.inHours;
        return 'In $hrs hour${hrs > 1 ? 's' : ''}';
      }
    } else {
      // Past today (overdue)
      final mins = diff.inMinutes.abs();
      if (mins < 60) {
        return 'Before $mins min';
      } else {
        final hrs = mins ~/ 60;
        return 'Before $hrs hour${hrs > 1 ? 's' : ''}';
      }
    }
  }
  

  // TOMORROW
  if (DateUtils.isSameDay(due, now.add(const Duration(days: 1)))) {
    return 'Tomorrow';
  }

  // YESTERDAY
  if (DateUtils.isSameDay(due, now.subtract(const Duration(days: 1)))) {
    return 'Yesterday';
  }

  // FUTURE
  if (diff.inDays > 0) {
    return 'After ${diff.inDays} day${diff.inDays > 1 ? 's' : ''}';
  }

  // PAST
  final pastDays = diff.inDays.abs();
  return 'Before $pastDays day${pastDays > 1 ? 's' : ''}';
}

Widget _participantRow(List doers, List viewers) {
  const int maxVisible = 4;

  final List<Map<String, dynamic>> allParticipants = [
    ...doers.map((u) => {...u, 'type': 'doer'}),
    ...viewers.map((u) => {...u, 'type': 'viewer'}),
  ];

  return Wrap(
    spacing: 6,
    runSpacing: 4,
    children: [
      ...allParticipants.take(maxVisible).map((user) {
        final String name = user['name'] ?? '';
        final bool isDoer = user['type'] == 'doer';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isDoer
                ? Colors.green.shade50
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDoer ? Colors.green : Colors.black87,
            ),
          ),
        );
      }),

      if (allParticipants.length > maxVisible)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "+${allParticipants.length - maxVisible}",
            style: const TextStyle(fontSize: 11),
          ),
        ),
    ],
  );
}



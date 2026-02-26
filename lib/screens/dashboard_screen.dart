import 'dart:async';
import 'package:flutter/material.dart';
import '../services/dashboard_service.dart';
import '../screens/create_task_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/task_list_service.dart';
import '../services/task_complete_service.dart';
import '../services/task_completed_list_service.dart';
import '../services/task_delete_service.dart';
import '../services/delegate_list_service.dart';
import '../services/category_service.dart';
import '../services/add_remark_service.dart';
import '../services/task_remarks_service.dart';
import '../services/task_mark_incomplete_service.dart';
import '../services/task_handle_today_service.dart';
import '../services/task_approval_service.dart';
import 'set_credentials_screen.dart';
import 'package:intl/intl.dart';
import '../screens/all_tasks_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/auth_state.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'participants_screen.dart';
import 'notifications_screen.dart';







class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  
  int selectedIndex = 0; // 0-Pending, 1-InProgress, 2-Urgent, 3-Overdue

  final ScrollController _scrollController = ScrollController();

  List tasks = [];
  bool isLoading = false;
  bool hasMore = true;
  int offset = 0;
  bool isDailyMode = false; // 🔥 ADD

  List actionTodayTasks = [];
  List actionOverdueTasks = [];

  List pendingApprovalTasks = [];

  bool isDashboardReady = false;




  // 🔹 STATIC FILTER STATE (UI only)
  String filterDueDate = 'any'; // any, today, week
  List<String> filterDelegates = [];
  List<String> filterPriority = [];

  bool isAllRecordsMode = false;


  List<Map<String, dynamic>> categories = [];
  List<int> selectedCategoryIds = [];
  bool isCategoryLoading = false;

  bool isSearching = false;
  TextEditingController searchController = TextEditingController();

  String searchQuery = '';        // ✅ ADD THIS
  Timer? _searchDebounce;         // ✅ ADD THIS

  bool isCompletedView = false;

  int unreadNotificationCount = 0;
  bool isNotificationLoading = false;





  List<Map<String, dynamic>> delegates = [];
  List<int> selectedDelegateIds = [];
  bool isDelegateLoading = false;



  int? userId;

  String currentFilter = 'TODAY'; 
  // ALL, TODAY, OVERDUE, UPCOMING


  Set<int> completingTaskIds = {};

  Map<String, List<Map<String, dynamic>>> _groupUpcomingTasks(
      List<dynamic> taskList) {

    final Map<String, List<Map<String, dynamic>>> grouped = {
      'NON_RECURRING': [],
      'DAILY': [],
      'WEEKLY': [],
      'MONTHLY': [],
      'YEARLY': [],
    };

    for (var task in taskList) {
      final String? recurrence =
          task['recurrence_type']?.toString().toLowerCase();

      if (recurrence == null ||
          recurrence.isEmpty ||
          recurrence == 'none') {
        grouped['NON_RECURRING']!.add(Map<String, dynamic>.from(task));
      } else {
        final key = recurrence.toUpperCase();
        if (grouped.containsKey(key)) {
          grouped[key]!.add(Map<String, dynamic>.from(task));
        } else {
          grouped['NON_RECURRING']!.add(Map<String, dynamic>.from(task));
        }
      }
    }

    return grouped;
  }


Future<void> _initializeDashboard() async {
  await _loadUserAndLoadTasks();
  await _loadActionTasks(reset: true);
  await _loadNotificationsBadge();   // 🔔 ADD THIS

}


  @override
  void initState() {
    super.initState();
    
//    _initializeDashboard();

     WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeDashboard();
      });    


    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !isLoading &&
          hasMore) {
          
        if (isAllRecordsMode) {
          _loadAllRecords();
        } else if (selectedIndex == 4) {
          _loadCompletedTasks();
        } else {
          _loadTasks(filter: currentFilter);
        }
          
          
        
      }
    });
  }

Future<void> _refreshCurrentView() async {
  if (selectedIndex == 0 &&
      !isCompletedView &&
      !isAllRecordsMode) {
    await _loadActionTasks(reset: true);
  } else if (isCompletedView) {
    await _loadCompletedTasks(reset: true);
  } else if (isAllRecordsMode) {
    await _loadAllRecords(reset: true);
  } else {
    await _loadTasks(
      reset: true,
      filter: currentFilter,
    );
  }
}


Future<void> _loadNotificationsBadge() async {
  if (userId == null) return;

  try {
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
        unreadNotificationCount = data['unread_count'] ?? 0;
      });
    }
  } catch (e) {
    debugPrint("Notification badge error: $e");
  }
}



    Future<void> _loadDelegates() async {


      if (userId == null) return;

      //debugPrint('🟢 _loadDelegates() called');
      //debugPrint('🟢 userId = $userId');    


      setState(() => isDelegateLoading = true);

      delegates = await DelegateListService.fetchDelegates(
        userId: userId!,
      );

      //debugPrint('🟢 Delegates fetched: ${delegates.length}');
      //debugPrint('🟢 Delegates data: $delegates');      

      setState(() => isDelegateLoading = false);
    }

    Future<void> _loadCategories() async {

  //debugPrint('🟣 _loadCategories() called');
  //debugPrint('🟣 userId = $userId');    

      if (userId == null) return;

      setState(() => isCategoryLoading = true);

      categories = await CategoryService.fetchCategories(
        userId: userId!, // 🔥 REQUIRED
      );

      //debugPrint('🟢 Categories loaded: $categories');

 //debugPrint('🟣 categories length = ${categories.length}');
  //debugPrint('🟣 categories data = $categories');
  
      setState(() => isCategoryLoading = false);
    }


Future<void> _loadActionTasks({bool reset = false}) async {
  if (isLoading) return;

  if (reset) {
    pendingApprovalTasks.clear();
    actionTodayTasks.clear();
    actionOverdueTasks.clear();
    isDashboardReady = false;   // 🔥 ADD THIS

  }

  setState(() => isLoading = true);

  try {
    final response = await http.post(
      Uri.parse('${baseUrl}action_dashboard.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'delegate_ids': selectedDelegateIds,
        'priorities': filterPriority,
        'category_ids': selectedCategoryIds,
        'search': searchQuery.isNotEmpty ? searchQuery : null,

      }),
    );

    // print("RAW RESPONSE:");
    // print(response.body);

    final data = jsonDecode(response.body);

    if (data['status'] == true) {
      setState(() {
        pendingApprovalTasks =
            List<Map<String, dynamic>>.from(data['data']['pending'] ?? []);

        actionTodayTasks =
            List<Map<String, dynamic>>.from(data['data']['today'] ?? []);

        actionOverdueTasks =
            List<Map<String, dynamic>>.from(data['data']['overdue'] ?? []);

        isDashboardReady = true; // 🔥 important

      });
    } else {
      debugPrint("Action API Error: ${data['message']}");
    }
  } catch (e) {
    debugPrint("Action Load Error: $e");

    setState(() {
      isDashboardReady = true;
    });

  }

  setState(() => isLoading = false);
}



Future<void> _markTaskIncomplete(Map task) async {
  final int taskId = task['task_id'];

  final success = await TaskMarkIncompleteService.markIncomplete(
    taskId: taskId,
    userId: userId!,
  );

  if (success) {

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Task moved back to pending')),
    );

    await _refreshCurrentView();   // 🔥 THIS IS THE FIX
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to update task')),
    );
  }
}


Future<void> _handleApproval(Map task, String action) async {
  final int taskId = task['task_id'];

  final result = await TaskApprovalService.handleApproval(
    taskId: taskId,
    userId: userId!,
    action: action,
  );

  if (result['status'] == true) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message'])),
    );

    await _refreshCurrentView(); // 🔥 important
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message'] ?? 'Failed')),
    );
  }
}

    

Widget _categoryTile(
  int id,
  String name,
  void Function(void Function()) setModalState,
) {
  final bool selected = selectedCategoryIds.contains(id);

  return CheckboxListTile(
    value: selected,
    title: Text(name),
    onChanged: (v) {
      setModalState(() {
        v!
            ? selectedCategoryIds.add(id)
            : selectedCategoryIds.remove(id);
      });
    },
  );
}


Future<void> _handleTaskForToday(
  Map task, {
  required String message,
}) async {
  final int taskId = task['task_id'];

  final success = await TaskHandleTodayService.handleToday(
    taskId: taskId,
    userId: userId!,
  );

  if (success) {
    setState(() {
      tasks.removeWhere((t) => t['task_id'] == taskId);

      actionTodayTasks.removeWhere((t) => t['task_id'] == taskId);
      actionOverdueTasks.removeWhere((t) => t['task_id'] == taskId);

    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to update task')),
    );
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
              userId: userId!,
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

String formatExtendedDate(String date) {
  final dt = DateTime.parse(date).toLocal();
  return DateFormat('dd-MMM-yy h:mm a').format(dt);
}


Future<bool?> _showAddRemarkDialog(Map task) async {
  final TextEditingController remarkController = TextEditingController();

  bool isLoading = false;
  bool extendTimeline = false;
  DateTime? selectedDateTime;

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  /// HEADER
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Add Remark',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed:
                            isLoading ? null : () => Navigator.pop(context),
                      )
                    ],
                  ),

                  const SizedBox(height: 8),

                  /// REMARK INPUT
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextField(
                      controller: remarkController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Enter remark',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// EXTEND TIMELINE CHECKBOX
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Extend timeline?',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    value: extendTimeline,
                    onChanged: (v) {
                      setModalState(() {
                        extendTimeline = v ?? false;
                        if (!extendTimeline) {
                          selectedDateTime = null;
                        }
                      });
                    },
                  ),

                  /// DATE TIME PICKER
                  if (extendTimeline) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(
                            const Duration(days: 1),
                          ),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );

                        if (date == null) return;

                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );

                        if (time == null) return;

                        setModalState(() {
                          selectedDateTime = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                selectedDateTime == null
                                    ? 'Select extended date & time'
                                    : formatDueDate(
                                        selectedDateTime!
                                            .toIso8601String(),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  /// ACTIONS
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isLoading
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: isLoading
                              ? null
                              : () async {
                                  final remark =
                                      remarkController.text.trim();

                                  if (remark.isEmpty) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Remark cannot be empty'),
                                      ),
                                    );
                                    return;
                                  }

                                  if (extendTimeline &&
                                      selectedDateTime == null) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Please select extended date'),
                                      ),
                                    );
                                    return;
                                  }

                                  setModalState(() => isLoading = true);

                                  final res =
                                      await AddRemarkService.addRemark(
                                    taskId: task['task_id'],
                                    userId: userId!,
                                    description: remark,
                                    extendedDate: extendTimeline
                                        ? selectedDateTime!
                                            .toIso8601String()
                                        : null,
                                  );

                                  setModalState(() => isLoading = false);

                                  if (res['success'] == true) {
                                      Navigator.pop(context, true); // 👈 IMPORTANT
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Remark added successfully')),
                                      );
                                  } else {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          res['error'] ??
                                              'Something went wrong',
                                        ),
                                      ),
                                    );
                                  }
                                },
                          child: isLoading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Save',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}




  Future<void> _loadUserAndLoadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getInt('user_id');

    if (userId != null) {
      await _loadCategories(); // ✅ THIS WAS MISSING     
    } else {
      debugPrint('❌ user_id not found in SharedPreferences');
    }
  }
  
void _openFilterSheet() async {

  if (delegates.isEmpty && !isDelegateLoading) {
    await _loadDelegates();
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            color: Colors.white, // ✅ white background
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  /// HEADER
                  Row(
                    children: [
                      // CLOSE BUTTON
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),

                      const Expanded(
                        child: Text(
                          'Filter Tasks',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            filterPriority.clear();
                            selectedCategoryIds.clear();
                            selectedDelegateIds.clear();
                          });
                        },
                        child: const Text('Clear'),
                      ),
                    ],
                  ),

                  const Divider(height: 32),

                  /// 1️⃣ PRIORITY
                  const Text(
                    'Priority',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    children: ['URGENT', 'NORMAL', 'LOW'].map((p) {
                      final selected = filterPriority.contains(p);
                      return ChoiceChip(
                        label: Text(p),
                        selected: selected,
                        selectedColor: Colors.red.shade100,
                        onSelected: (v) {
                          setModalState(() {
                            v
                                ? filterPriority.add(p)
                                : filterPriority.remove(p);
                          });
                        },
                      );
                    }).toList(),
                  ),

                  const Divider(height: 32),

                  /// CATEGORY
                  const Text(
                    'Category',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),

                  if (isCategoryLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((c) {
                        final int id = int.parse(c['id'].toString());
                        final bool selected = selectedCategoryIds.contains(id);

                        return FilterChip(
                          label: Text(
                            c['category_name'],
                            style: const TextStyle(fontSize: 13),
                          ),
                          selected: selected,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          onSelected: (v) {
                            setModalState(() {
                              v
                                  ? selectedCategoryIds.add(id)
                                  : selectedCategoryIds.remove(id);
                            });
                          },
                        );
                      }).toList(),
                    ),
                  

                  const Divider(height: 32),

/// DELEGATED TO
const Text(
  'Delegated To',
  style: TextStyle(fontWeight: FontWeight.w600),
),
const SizedBox(height: 8),

if (isDelegateLoading)
  const Center(child: CircularProgressIndicator())
else
  Wrap(
    spacing: 8,
    runSpacing: 8,
    children: delegates.map((d) {
      final int id = int.parse(d['user_id'].toString());
      final bool selected = selectedDelegateIds.contains(id);
      final String name = d['name'] ?? '';
      final String? photo = d['profile_photo'];

return FilterChip(
  label: Text(
    name,
    style: const TextStyle(fontSize: 13),
  ),
  selected: selected,
  selectedColor: Colors.green.shade100,
  backgroundColor: Colors.grey.shade100,
  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  onSelected: (v) {
    setModalState(() {
      v
          ? selectedDelegateIds.add(id)
          : selectedDelegateIds.remove(id);
    });
  },
);

      
    }).toList(),
  ),


                  const SizedBox(height: 24),

                  /// APPLY
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);

                        setState(() {
                          selectedIndex = 0;

                          isCompletedView = false;
                          isAllRecordsMode = false;
                          isDailyMode = false;

                          tasks.clear();
                          actionTodayTasks.clear();
                          actionOverdueTasks.clear();

                          offset = 0;
                          hasMore = true;
                        });

                        await _loadActionTasks(reset: true);
                      },
                      child: const Text('Apply Filters'),
                    ),
                  ),
                  
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

 


Future<void> _confirmDelete(Map task) async {
  final bool? confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Task'),
      content: const Text(
        'Are you sure you want to delete this task? This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            'Delete',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  );

  if (confirm == true) {
    _deleteTask(task);
  }
}


Future<void> _deleteTask(Map task) async {
  final int taskId = task['task_id'];

  final success = await TaskDeleteService.deleteTask(
    taskId: taskId,
    userId: userId!,
  );

  if (success) {
    setState(() {
      tasks.removeWhere((t) => t['task_id'] == taskId);

      actionTodayTasks.removeWhere((t) => t['task_id'] == taskId);
      actionOverdueTasks.removeWhere((t) => t['task_id'] == taskId);

    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Task deleted')),
    );

    /// 🔥 IMPORTANT: if in Completed tab, reload safely
    if (selectedIndex == 4) {
      await _loadCompletedTasks(reset: true);
    }
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to delete task')),
    );
  }
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


Color _priorityColor(String priority) {
  switch (priority.toUpperCase()) {
    case 'URGENT':
      return Colors.orange;
    case 'LOW':
      return Colors.blue;
    case 'NORMAL':
    default:
      return Colors.green;
  }
}


Future<void> _completeTask(Map task) async {
  final int taskId = task['task_id'];

  if (completingTaskIds.contains(taskId)) return;

  setState(() {
    completingTaskIds.add(taskId);
  });

  final success = await TaskCompleteService.completeTask(
    userId: userId!,
    taskId: taskId,
  );

  if (success) {
    setState(() {
      tasks.removeWhere((t) => t['task_id'] == taskId);

      actionTodayTasks.removeWhere((t) => t['task_id'] == taskId);
      actionOverdueTasks.removeWhere((t) => t['task_id'] == taskId);

      completingTaskIds.remove(taskId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Task marked as completed')),
    );
  } else {
    setState(() {
      completingTaskIds.remove(taskId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to complete task')),
    );
  }
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
    userId: userId!,
    offset: offset,
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

Future<void> _confirmSnooze(Map task) async {
  final bool? confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Snooze Task'),
      content: const Text(
        'This task will be hidden for today and will reappear tomorrow.\n\nDo you want to continue?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            'Snooze',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  );

  if (confirm == true) {
    await _handleTaskForToday(
      task,
      message:
          'Snoozed for today. It will reappear tomorrow.',
    );
  }
}


/// 🧾 TASK TILE (Chat-style)
/// 🧾 COMPACT TASK TILE (Dense + Left Status Bar)
Widget _taskTile(Map task) {
  final String title = task['title'] ?? '';
  final String priority = task['priority'] ?? 'NORMAL';
  final bool isOverdue = task['is_overdue'] == true;
  final String? dueDate = task['due_date'];
  final String? categoryName = task['category']?['category_name'];
  final int remarksCount = task['remarks_count'] ?? 0;

  final bool isCompletionRequested =
      task['status'] == 'COMPLETION_REQUESTED';

 
 final bool isCreator =
    int.tryParse(task['created_by'].toString()) == userId;

  final participantsRaw = task['participants'];
  final List delegates = task['delegates'] ?? [];
  
  final Map<String, dynamic> participants =
      task['participants'] ?? {};

  final List doers =
      List<Map<String, dynamic>>.from(participants['doers'] ?? []);

  final List viewers =
      List<Map<String, dynamic>>.from(participants['viewers'] ?? []);
  

  final String? recurrenceType =
      task['recurrence_type']?.toString().toLowerCase();

  final bool isRecurring =
      recurrenceType != null &&
      recurrenceType.isNotEmpty &&
      recurrenceType != 'none';

  final int recurrenceInterval =
      int.tryParse(task['recurrence_interval']?.toString() ?? '1') ?? 1;

  final int missedDays =
      task['daily_meta']?['missed_days'] ?? 0; // future-safe

  final bool isCompleted = task['completed_at'] != null;
  final String? nextDueDate =
    task['next_due_date'] ?? task['due_date'];

  final bool canSnooze =
      !isCompleted &&
      !isCompletionRequested &&
        (selectedIndex == 0); // Action tab
      


  final Color statusColor = isOverdue
      ? Colors.red
      : priority == 'URGENT'
          ? Colors.orange
          : isRecurring
              ? _recurrenceColor(recurrenceType)
              : Colors.green;

//debugPrint("TASK ID: ${task['task_id']}");
//debugPrint("DUE_DATE: ${task['due_date']}");
//debugPrint("NEXT_DUE_DATE: ${task['next_due_date']}");              
 
  
  return InkWell(
    onTap: () async {
      // optional: open edit
    },
    child: Container(
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _recurrenceColor(recurrenceType).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _recurrenceLabel(recurrenceType, recurrenceInterval),
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
               

                if (isCompletionRequested)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Pending Approval',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                  ),


                /// DESCRIPTION (compact)
                if ((task['description'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      task['description'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),



                /// META LINE

Row(
  children: [
    Expanded(
      child: Row(
        children: [
          if (!isRecurring)
            Text(
              priority,
              style: TextStyle(
                fontSize: 12,
                fontWeight: priority.toUpperCase() == 'URGENT'
                    ? FontWeight.w600
                    : FontWeight.normal,
                color: priority.toUpperCase() == 'URGENT'
                    ? Colors.red
                    : Colors.grey.shade700,
              ),
            ),

          const SizedBox(width: 6),
          const Text(' • ', style: TextStyle(color: Colors.grey)),

          if (categoryName != null) ...[
            Flexible(
              child: Text(
                categoryName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            const Text(' • ', style: TextStyle(color: Colors.grey)),
          ],

          Flexible(
            child: Text(
              isCompleted
                  ? (nextDueDate != null
                      ? 'Completed ${formatExtendedDate(task['completed_at'])} • Next ${formatDueDate(nextDueDate)}'
                      : 'Completed ${formatDueDate(task['completed_at'])}')
                  : formatDueDate(dueDate),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isCompleted
                    ? Colors.green
                    : isOverdue
                        ? Colors.red
                        : isRecurring
                            ? _recurrenceColor(recurrenceType)
                            : Colors.grey.shade600,
              ),

            ),
          ),
        ],
      ),
    ),

    if (remarksCount > 0) ...[
      const SizedBox(width: 6),
      InkWell(
        onTap: () => _openRemarksSheet(task),
        child: Row(
          mainAxisSize: MainAxisSize.min,
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
    ],
  ],
),

                  if (doers.isNotEmpty || viewers.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _participantRow(doers, viewers),
                  ],            

              ],
            ),
          ),


if (selectedIndex == 0 &&
    !isCompleted &&
    !isCompletionRequested)
  
  SizedBox(
  width: 48, // match IconButton default
  child: IconButton(
    padding: EdgeInsets.zero,
    icon: const Icon(
      Icons.snooze,
      color: Colors.red,
      size: 20,
    ),
    onPressed: () async {
      await _confirmSnooze(task);
    },
  ),
),


          /// MENU
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 18),
            onSelected: (value) async {

              if (value == 'approve') {
                _handleApproval(task, 'APPROVE');
              } else if (value == 'reject') {
                _handleApproval(task, 'REJECT');
              } else if (value == 'complete') {
                _completeTask(task);
              } else if (value == 'snooze_today') {

                  await _handleTaskForToday(
                    task,
                    message: 'Snoozed for today. It will reappear tomorrow.',
                  );


                  setState(() {
                    tasks.removeWhere((t) => t['task_id'] == task['task_id']);

                    actionTodayTasks.removeWhere((t) => t['task_id'] == task['task_id']);
                    actionOverdueTasks.removeWhere((t) => t['task_id'] == task['task_id']);
                  });
                  
                } else if (value == 'incomplete') {
                _markTaskIncomplete(task);
              } else if (value == 'remarks') {
                  final updated = await _showAddRemarkDialog(task);

                  if (updated == true) {
                    if (selectedIndex == 0 &&
                        !isCompletedView &&
                        !isAllRecordsMode) {
                      await _loadActionTasks(reset: true);
                    } else if (isCompletedView) {
                      await _loadCompletedTasks(reset: true);
                    } else if (isAllRecordsMode) {
                      await _loadAllRecords(reset: true);
                    } else {
                      await _loadTasks(
                        reset: true,
                        filter: currentFilter,
                      );
                    }
                  }
                } else if (value == 'edit') {
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
                  await _loadActionTasks(reset: true);
                }
              } else if (value == 'delete') {
                _confirmDelete(task);
              }
            },
            itemBuilder: (context) {

              /// 🔥 PENDING APPROVAL (CREATOR VIEW)
              if (isCompletionRequested && isCreator) {
                return [
                  const PopupMenuItem(
                    value: 'approve',
                    child: Text(
                      'Approve',
                      style: TextStyle(color: Colors.green),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'reject',
                    child: Text(
                      'Reject',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ];
              }

              /// COMPLETED TASK
              if (task['completed_at'] != null) {
                return const [
                  PopupMenuItem(
                    value: 'incomplete',
                    child: Text('Mark as Incomplete'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ];
              }

              /// NORMAL TASK
              return [
                const PopupMenuItem(
                  value: 'complete',
                  child: Text('Mark as Complete'),
                ),
                const PopupMenuItem(
                  value: 'remarks',
                  child: Text('Add Update'),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit'),
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
    ),
  );
}

/// 🗂 DASHBOARD CATEGORY STRIP
Widget _categoryStrip() {
  if (isCategoryLoading || categories.isEmpty) {
    return const SizedBox.shrink();
  }

  final bool isAllSelected = selectedCategoryIds.isEmpty;

  return Container(
    height: 30,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [

        /// 🔘 ALL CHIP
        _categoryChip(
          label: 'All',
          selected: isAllSelected,

            onTap: () async {
              setState(() {
                selectedCategoryIds.clear();

                selectedIndex = 0;
                isCompletedView = false;
                isAllRecordsMode = false;
                isDailyMode = false;

                tasks.clear();
                actionTodayTasks.clear();
                actionOverdueTasks.clear();
                offset = 0;
                hasMore = true;
              });

              await _loadActionTasks(reset: true);
            },
          
        ),

        const SizedBox(width: 8),

        /// 🔘 CATEGORY CHIPS
        ...categories.map((c) {
          final int id = int.parse(c['id'].toString());
          final bool selected = selectedCategoryIds.contains(id);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _categoryChip(
              label: c['category_name'],
              selected: selected,
                onTap: () async {
                  //debugPrint("🟢 CATEGORY CLICKED: $id");

                  setState(() {
                    selectedCategoryIds
                      ..clear()
                      ..add(id);

                    // Force switch to Action tab
                    selectedIndex = 0;
                    isCompletedView = false;
                    isAllRecordsMode = false;
                    isDailyMode = false;

                    tasks.clear();
                    actionTodayTasks.clear();
                    actionOverdueTasks.clear();
                    offset = 0;
                    hasMore = true;
                  });

                  await _loadActionTasks(reset: true);
                },              
            ),
          );
        }).toList(),
      ],
    ),
  );
}

/// 🏷 CATEGORY CHIP
Widget _categoryChip({
  required String label,
  required bool selected,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? Colors.green.shade50 : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? Colors.green : Colors.grey.shade300,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: selected ? Colors.green : Colors.grey.shade700,
        ),
      ),
    ),
  );
}

  
Widget _header(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            axis: Axis.horizontal,
            child: child,
          ),
        );
      },
      child: isSearching ? _searchHeader() : _normalHeader(),
    ),
  );
}


Widget _normalHeader() {
  return Row(
    key: const ValueKey('normalHeader'),
    children: [

      /// ☰ LEFT MENU
      PopupMenuButton<String>(
        icon: const Icon(Icons.menu, size: 24),
        onSelected: (value) async {

          if (value == 'logout') {
            _confirmLogout();
          }


          if (value == 'profile') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SetCredentialsScreen(),
              ),
            );
          }

          if (value == 'participants') {

            //debugPrint('🟢 userId value = $userId');

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ParticipantsScreen(userId: userId!),
              ),
            );
          }
          


          if (value == 'completed') {
            setState(() {
              isDailyMode = false;
              selectedIndex = 0; // All Due
              isCompletedView = true;   // ✅ ADD THIS
              tasks.clear();
              offset = 0;
              hasMore = true;
            });

            await _loadCompletedTasks(reset: true);
          }

          if (value == 'daily') {
            //debugPrint('🟢 DAILY MENU CLICKED');

            setState(() {
              isDailyMode = true;
              selectedIndex = 2; // All Due
              isCompletedView = false;  // ✅ IMPORTANT
              currentFilter = 'ALL';
              tasks.clear();
              offset = 0;
              hasMore = true;
            });

             // debugPrint('🟢 isDailyMode = $isDailyMode');
             // debugPrint('🟢 currentFilter = $currentFilter');

            await _loadTasks(reset: true, filter: currentFilter);
          }
          if (value == 'all_tasks') {
            setState(() {
              isAllRecordsMode = true;
              isDailyMode = false;
              isCompletedView = false;

              tasks.clear();
              offset = 0;
              hasMore = true;
            });

            await _loadAllRecords(reset: true);
          }          
                      
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'completed',
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, size: 18),
                SizedBox(width: 8),
                Text('Completed Tasks'),
              ],
            ),
          ),
          /* PopupMenuItem(
            value: 'daily',
            child: Row(
              children: [
                Icon(Icons.repeat, size: 18),
                SizedBox(width: 8),
                Text('Daily Tasks'),
              ],
            ),
          ), */
         PopupMenuItem(
            value: 'all_tasks',
            child: Row(
              children: [
                Icon(Icons.list_alt, size: 18),
                SizedBox(width: 8),
                Text('All Tasks'),
              ],
            ),
          ),   
          PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person_outline, size: 18),
                  SizedBox(width: 8),
                  Text('Profile'),
                ],
              ),
            ),   

          PopupMenuItem(
            value: 'participants',
            child: Row(
              children: [
                Icon(Icons.group_outlined, size: 18),
                SizedBox(width: 8),
                Text('Participants'),
              ],
            ),
          ),


          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'logout',
            child: Row(
              children: const [
                Icon(Icons.logout, size: 18, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  'Logout',
                  style: TextStyle(color: Colors.red),
                ),
              ],
            ),
          ),

        ],
      ),

      const SizedBox(width: 6),

      /// 🧠 TITLE
      const Text(
        'TaskIQ',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
      ),

      const Spacer(),

      /// 🔍 SEARCH
      IconButton(
        icon: const Icon(Icons.search, size: 24),
        onPressed: () {
          setState(() => isSearching = true);
        },
      ),

      /// 🎛 FILTER
      IconButton(
        icon: const Icon(Icons.tune, size: 24),
        onPressed: _openFilterSheet,
      ),

      /// 🔔 NOTIFICATION
      Stack(
        children: [
          IconButton(
            icon: Icon(
              unreadNotificationCount > 0
                  ? Icons.notifications
                  : Icons.notifications_none,
              size: 24,
            ),
            onPressed: () async {
              final refreshed = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>  NotificationsScreen(),
                ),
              );

              if (refreshed == true) {
                await _loadNotificationsBadge();
              }
            },
          ),

          if (unreadNotificationCount > 0)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  unreadNotificationCount > 99
                      ? '99+'
                      : unreadNotificationCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),

      /// ➕ ADD
      IconButton(
      
        icon: const Icon(
          Icons.add_circle,
          color: Colors.green,
          size: 30,
        ),
        onPressed: () async {
          final shouldRefresh = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreateTaskScreen(),
            ),
          );

          if (shouldRefresh == true) {

            if (selectedIndex == 0) {
              await _loadActionTasks(reset: true);
            } else {
              await _loadTasks(
                reset: true,
                filter: currentFilter,
              );
            }
          }
          
        },
      ),
    ],
  );
}

Future<void> _confirmLogout() async {
  final bool? confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Logout'),
      content: const Text('Are you sure you want to logout?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            'Logout',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  );

  if (confirm == true) {
    await _logout();
  }
}

Future<void> _logout() async {

  // 🔥 Sign out Firebase
  await FirebaseAuth.instance.signOut();

  // 🔥 Clear backend login state
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('user_id');
  await prefs.remove('firebase_uid');

  // 🔥 Update backend flag
  AuthState.backendReady.value = false;

}


Future<void> _loadAllRecords({bool reset = false}) async {
  if (isLoading) return;

  if (reset) {
    offset = 0;
    tasks.clear();
    hasMore = true;
  }

  setState(() => isLoading = true);

  try {
    final response = await http.post(
      Uri.parse('${baseUrl}all_task_list.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'limit': 30,
        'offset': offset,
      }),
    );

    final data = jsonDecode(response.body);

    if (data['status'] == true) {
      final List newTasks = data['data']['tasks'];

      setState(() {
        tasks.addAll(newTasks);
        offset += 10;
        hasMore = data['data']['has_more'];
      });
    }
  } catch (e) {
    debugPrint("Error loading all records: $e");
  }

  setState(() => isLoading = false);
}



void _onSearchChanged(String value) {
  searchQuery = value.trim();
}

Future<void> _executeSearch() async {

  if (selectedIndex == 0 &&
      !isCompletedView &&
      !isAllRecordsMode) {

    await _loadActionTasks(reset: true);

  } else if (isCompletedView) {

    await _loadCompletedTasks(reset: true);

  } else if (isAllRecordsMode) {

    await _loadAllRecords(reset: true);

  } else {

    await _loadTasks(
      reset: true,
      filter: currentFilter,
    );
  }
}


Widget _searchHeader() {
  return Row(
    key: const ValueKey('searchHeader'),
    children: [
      Expanded(
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(22),
          ),
          child: TextField(
            controller: searchController,
            autofocus: true,
            textInputAction: TextInputAction.search, // 👈 keyboard shows SEARCH
            decoration: InputDecoration(
              hintText: 'Search tasks…',
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.search, size: 18),

              // 👇 ADD THIS (manual search button)
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: () async {
                  searchQuery = searchController.text.trim();
                  await _executeSearch();
                },
              ),
            ),

            // 👇 ENTER key triggers search
            onSubmitted: (value) async {
              searchQuery = value.trim();
              await _executeSearch();
            },
          ),
        ),
      ),

      const SizedBox(width: 8),

      /// ❌ CLOSE
      IconButton(
        icon: const Icon(Icons.close),
        onPressed: () async {
          searchController.clear();
          searchQuery = '';
          setState(() => isSearching = false);
          await _executeSearch(); // reload clean state properly
        },
      ),
    ],
  );
}


Widget _buildFriendlyEmptyState() {
  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          const Icon(
            Icons.task_alt,
            size: 70,
            color: Colors.green,
          ),

          const SizedBox(height: 20),


          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () async {
                final created = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateTaskScreen(),
                  ),
                );

                if (created == true) {
                  await _loadTasks(reset: true, filter: currentFilter);
                }
              },
              icon: const Icon(Icons.add),
              label: const Text(
                "Create A New Task",
                style: TextStyle(fontSize: 15),
              ),
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            "Or tap the green + button anytime.",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    ),
  );
}



    Future<void> _loadTasks({
      bool reset = false,
      String filter = 'TODAY',
    }) async {
  
    if (isLoading) return;

    if (reset) {
      offset = 0;
      tasks.clear();
      hasMore = true;
    }

    setState(() => isLoading = true);

    // debugPrint('🟡 LOAD TASKS CALLED');
    // debugPrint('🟡 isDailyMode = $isDailyMode');


    final result = await TaskListService.fetchTasks(
      userId: userId!,
      offset: offset,
      filter: filter,
      delegateIds: selectedDelegateIds,
      priorities: filterPriority,
      categoryIds: selectedCategoryIds, // ✅ ADD
      search: searchQuery.isNotEmpty ? searchQuery : null, // ✅
      isDaily: isDailyMode ? 1 : null, // 🔥 ADD


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

  @override
  void dispose() {
    _searchDebounce?.cancel(); // ✅ ADD
    _scrollController.dispose();
    super.dispose();
  }


@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.white,

    body: Column(
      children: [
        SafeArea(
          bottom: false,
          child: _header(context),
        ),

        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _categoryStrip(),
        ),

        Divider(
          height: 1,
          thickness: 0.6,
          color: Colors.grey.shade300,
        ),

        Expanded(
          child: Column(
            children: [

              /// 🔹 Header ONLY for completed view
              if (isCompletedView || isAllRecordsMode)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Icon(
                        isCompletedView ? Icons.check_circle : Icons.list_alt,
                        size: 16,
                        color: isCompletedView ? Colors.green : Colors.blue,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isCompletedView ? 'Completed Tasks' : 'All Tasks',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      if (isAllRecordsMode) {
                        await _loadAllRecords(reset: true);
                      } else if (isCompletedView) {
                        await _loadCompletedTasks(reset: true);
                      } else {
                        await _refreshCurrentView();
                      }
                    },
                    child: Builder(
                      builder: (context) {

                        /// 🔹 ACTION TAB (Today + Overdue merged)
                        if (selectedIndex == 0 &&
                            !isCompletedView &&
                            !isAllRecordsMode) {

                            // 🔹 Wait until first API response
                            if (!isDashboardReady) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            // 🔹 After API loaded → decide empty state
                            if (actionTodayTasks.isEmpty &&
                                actionOverdueTasks.isEmpty &&
                                pendingApprovalTasks.isEmpty) {
                              return _buildFriendlyEmptyState();
                            }                   

                          return ListView(
                            controller: _scrollController,
                            padding: const EdgeInsets.only(bottom: 80),
                            children: [

                              // 🟠 PENDING APPROVAL
                              if (pendingApprovalTasks.isNotEmpty) ...[
                                _sectionHeader(
                                  title: "PENDING APPROVAL",
                                  count: pendingApprovalTasks.length,
                                  color: Colors.orange,
                                ),
                                ...pendingApprovalTasks.map((t) => _taskTile(t)),
                              ],

                              // 🟢 TODAY
                              if (actionTodayTasks.isNotEmpty) ...[
                                _sectionHeader(
                                  title: "TODAY",
                                  count: actionTodayTasks.length,
                                  color: Colors.green,
                                ),
                                ...actionTodayTasks.map((t) => _taskTile(t)),
                              ],                              

                              // 🔴 OVERDUE
                              if (actionOverdueTasks.isNotEmpty) ...[
                                _sectionHeader(
                                  title: "OVERDUE",
                                  count: actionOverdueTasks.length,
                                  color: Colors.red,
                                ),
                                ...actionOverdueTasks.map((t) => _taskTile(t)),
                              ],

                             
                            ],
                            
                          );
                        }
                        

                        /// 🔹 NORMAL VIEW (Upcoming / All / Completed)
                        if (tasks.isEmpty &&
                            !isLoading &&
                            !isCompletedView &&
                            !isAllRecordsMode &&
                            searchQuery.isEmpty) {
                          return _buildFriendlyEmptyState();
                        }

/// 🔹 UPCOMING VIEW WITH RECURRENCE GROUPING
if (selectedIndex == 1 &&
    !isCompletedView &&
    !isAllRecordsMode) {

  if (tasks.isEmpty && !isLoading) {
    return _buildFriendlyEmptyState();
  }

  final grouped = _groupUpcomingTasks(tasks);

  return ListView(
    controller: _scrollController,
    padding: const EdgeInsets.only(bottom: 80),
    children: [

      if (grouped['NON_RECURRING']!.isNotEmpty) ...[
        _sectionHeader(
          title: "NON-RECURRING",
          count: grouped['NON_RECURRING']!.length,
          color: Colors.green,
        ),
        ...grouped['NON_RECURRING']!
            .map((t) => _taskTile(t))
            .toList(),
      ],

      if (grouped['DAILY']!.isNotEmpty) ...[
        _sectionHeader(
          title: "DAILY",
          count: grouped['DAILY']!.length,
          color: Colors.green,
        ),
        ...grouped['DAILY']!
            .map((t) => _taskTile(t))
            .toList(),
      ],

      if (grouped['WEEKLY']!.isNotEmpty) ...[
        _sectionHeader(
          title: "WEEKLY",
          count: grouped['WEEKLY']!.length,
          color: Colors.blue,
        ),
        ...grouped['WEEKLY']!
            .map((t) => _taskTile(t))
            .toList(),
      ],

      if (grouped['MONTHLY']!.isNotEmpty) ...[
        _sectionHeader(
          title: "MONTHLY",
          count: grouped['MONTHLY']!.length,
          color: Colors.purple,
        ),
        ...grouped['MONTHLY']!
            .map((t) => _taskTile(t))
            .toList(),
      ],

      if (grouped['YEARLY']!.isNotEmpty) ...[
        _sectionHeader(
          title: "YEARLY",
          count: grouped['YEARLY']!.length,
          color: Colors.orange,
        ),
        ...grouped['YEARLY']!
            .map((t) => _taskTile(t))
            .toList(),
      ],

      if (hasMore)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
    ],
  );
}


                        return ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: tasks.length + 1,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, thickness: 0.6),
                          itemBuilder: (context, index) {
                            if (index < tasks.length) {
                              return _taskTile(tasks[index]);
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
                        );
                      },
                    ),
                  ),
                ),
                  


              
            ],
          ),
        ),
      ],
    ),

    bottomNavigationBar: BottomNavigationBar(
      currentIndex: selectedIndex,

      onTap: (i) async {

        setState(() {
          isDailyMode = false;
          isAllRecordsMode = false;
          selectedIndex = i;
          isCompletedView = false;
          tasks.clear();
          offset = 0;
          hasMore = true;
        });

        // 🔥 async calls must be OUTSIDE setState

        if (i == 0) {
          await _loadActionTasks(reset: true);
        } else if (i == 1) {
          currentFilter = 'UPCOMING';
          await _loadTasks(reset: true, filter: currentFilter);
        } /* else if (i == 2) {
          currentFilter = 'ALL';
          await _loadTasks(reset: true, filter: currentFilter);
        } */
      },

      
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.green,
      unselectedItemColor: Colors.grey,
      selectedFontSize: 11,
      unselectedFontSize: 11,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.flash_on),
          label: 'Action',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.event),
          label: 'Upcoming',
        ),
        /* BottomNavigationBarItem(
          icon: Icon(Icons.list_alt),
          label: 'All Due',
        ), */
      ],
    ),
  );
}


Widget _sectionHeader({
  required String title,
  required int count,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
    child: Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
}



  /// 🔹 CREATE TASK
  Future<void> _openCreateTask() async {
    final created = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateTaskScreen()),
    );

    if (created == true) {
      await _loadTasks(reset: true);
    }
    
  }
}

/// 🔍 SEARCH BAR (WhatsApp style)
Widget _searchBar() {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: TextField(
      decoration: InputDecoration(
        hintText: 'Search task',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );
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



String _initials(String name) {
  if (name.trim().isEmpty) return '?';

  final parts = name.trim().split(' ');
  if (parts.length == 1) {
    return parts[0][0].toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}


Widget _delegateAvatars(List delegates) {
  const int maxVisible = 3;

  return Row(
    children: [
      ...delegates.take(maxVisible).map((d) {
        final String name = d['name'] ?? '';
        final String? photo = d['profile_photo'];

        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Column(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey.shade300,
                child: ClipOval(
                  child: Image.network(
                    photo ?? '',
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Text(
                          _initials(name),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    },
                  ),
                ),
              ),              
              const SizedBox(height: 4),
              SizedBox(
                width: 50,
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        );
      }),

      if (delegates.length > maxVisible)
        Column(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey.shade200,
              child: Text(
                '+${delegates.length - maxVisible}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'More',
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
    ],
  );
}




class _delegateChip extends StatelessWidget {
  final String label;
  const _delegateChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}

class _actionButton extends StatelessWidget {
  final String text;
  const _actionButton(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        color: Colors.blue,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _actionIcon extends StatelessWidget {
  final IconData icon;
  final String label;

  const _actionIcon(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue, size: 22),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }
}


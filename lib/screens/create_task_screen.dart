import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/task_service.dart';
import '../services/category_service.dart';
import 'create_category.dart';
import 'category_management_screen.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CreateTaskScreen extends StatefulWidget {

final bool isEdit;
final Map<String, dynamic>? task;



const CreateTaskScreen({
  super.key,
  this.isEdit = false,
  this.task,
});  


  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();


  List<Map<String, dynamic>> categories = [];
  int? selectedCategoryId;
  bool loadingCategories = false;

  bool showDescription = false;

  String recurrenceType = 'none'; // none, daily, weekly, monthly, yearly
  List<int> weeklyDays = [];
  int? monthlyDay;
  int? yearlyMonth;
  int? yearlyDay;



  String deadlineType = 'IMMEDIATE'; // IMMEDIATE | DATE
  DateTime? selectedDeadline;


  bool showDailyUntilDone = false;

  List<Map<String, dynamic>> approvedParticipants = [];
  bool loadingParticipants = false;




  List<Map<String, dynamic>> selectedParticipants = [];
  bool loading = false;

  String assignType = 'SELF'; // SELF | PARTICIPANTS
  String priority = 'NORMAL';
  String recurrence = 'ONE_TIME';

  DateTime? deadline;
  int? userId;

  final List<int> watchers = [];

  // 🔥 LOAD USER ID
  @override
  void initState() {
    super.initState();
    _loadUserId();

    weeklyDays = [];

    

    if (widget.isEdit && widget.task != null) {
      final t = widget.task!;

      _titleCtrl.text = t['title'] ?? '';
      _descCtrl.text = t['description'] ?? '';
      priority = t['priority'] ?? 'NORMAL';
      
      assignType = t['task_type'] ?? 'SELF';

      selectedCategoryId = t['category']?['category_id'];

      showDailyUntilDone = t['show_daily_until_done'] == 1;

      // ✅ Deadline
      if (t['due_date'] != null &&
          t['due_date'].toString().isNotEmpty) {
        deadlineType = 'DATE';
        selectedDeadline = DateTime.parse(t['due_date']);
      }
      

      // 🔁 RECURRENCE STARTS HERE

      recurrenceType = (t['recurrence_type'] ?? 'none')
          .toString()
          .toLowerCase();

      if (recurrenceType == '' || recurrenceType == 'null') {
        recurrenceType = 'none';
      }


      if (recurrenceType == 'weekly' &&
          t['recurrence_days'] != null &&
          t['recurrence_days'].toString().isNotEmpty) {

        weeklyDays = t['recurrence_days']
            .toString()
            .split(',')
            .where((e) => e.isNotEmpty)
            .map((e) => int.parse(e))
            .toList();

      } else {
        weeklyDays = [];
      }

      // 👇 ADD THIS FOR PARTICIPANT PREFILL

      final participants = t['participants'];

      if (participants is Map) {

        final List doers = participants['doers'] ?? [];
        final List viewers = participants['viewers'] ?? [];

        if (doers.isNotEmpty || viewers.isNotEmpty) {

          assignType = 'PARTICIPANTS';

          selectedParticipants = [
            ...doers.map<Map<String, dynamic>>((p) => {
                  'id': p['user_id'],
                  'full_name': p['name'],
                  'role': 'DOER',
                }),
            ...viewers.map<Map<String, dynamic>>((p) => {
                  'id': p['user_id'],
                  'full_name': p['name'],
                  'role': 'VIEWER',
                }),
          ];

        } else {
          assignType = 'SELF';
          selectedParticipants = [];
        }

      } else {
        assignType = 'SELF';
        selectedParticipants = [];
      }



    }
       
  }

  



 Future<void> _loadCategories() async {
  if (userId == null) return;

  setState(() => loadingCategories = true);

  try {
    final res = await http.post(
      Uri.parse('https://backoffice.thecubeclub.co/task_apis/get_categories.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );

    final data = jsonDecode(res.body);



    if (data['success'] == true) {
      categories = List<Map<String, dynamic>>.from(data['categories']);

      if (!categories.any((c) => c['id'] == selectedCategoryId)) {
        selectedCategoryId = null;
      }
    }
  } catch (e) {
    debugPrint('Category load error: $e');
  }

  setState(() => loadingCategories = false);
}





  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getInt('user_id');

    if (userId != null) {
      _loadCategories();
      _loadApprovedParticipants();  // 🔥 IMPORTANT

    }

    setState(() {});
  }




Future<void> _loadApprovedParticipants() async {
  if (userId == null) return;

  setState(() => loadingParticipants = true);

  try {
    final res = await http.post(
      Uri.parse('https://backoffice.thecubeclub.co/task_apis/get_collaborations.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );

    final data = jsonDecode(res.body);

    print("API RESPONSE: $data");

    if (data['status'] == true) {
      final List rawList = data['data'];

      // Only keep APPROVED users
      approvedParticipants = rawList
          .where((u) => u['status'] == 'APPROVED')
          .map<Map<String, dynamic>>((u) => {
                'id': u['user_id'],
                'full_name': u['name'],
                'email': u['email'],
                'profile_photo': u['profile_photo'],
              })
          .toList();

      print("Approved Count: ${approvedParticipants.length}");
    }
  } catch (e) {
    debugPrint('Participant load error: $e');
  }

  setState(() => loadingParticipants = false);
}




  
Future<void> _pickDeadline() async {
  final pickedDate = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime.now(),
    lastDate: DateTime(2100),
  );

  if (pickedDate == null) return;

  final pickedTime = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.now(),
  );

  if (pickedTime == null) return;

  setState(() {
    selectedDeadline = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  });
}



  

  void d(String msg) {
    debugPrint('🟣 CREATE_TASK: $msg');
  }




  Future<void> _submit() async {
    debugPrint('🟢 SUBMIT ENTERED');

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    if (_titleCtrl.text.isEmpty) return;

    if (categories.isNotEmpty && selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select category')),
      );
      return;
    }
    

    if (deadlineType == 'DATE' && selectedDeadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select deadline')),
      );
      return;
    }


      if (assignType == 'PARTICIPANTS' &&
      selectedParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please assign at least one user')),
      );
      return;
    }

    setState(() => loading = true);

    DateTime finalDeadline =
        deadlineType == 'IMMEDIATE'
            ? DateTime.now()
            : selectedDeadline!;    

    debugPrint('🟢 Show Daily: $showDailyUntilDone');

    if (recurrenceType == 'weekly' && weeklyDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one weekday')),
      );
      return;
    }




    final result = widget.isEdit
        ? await TaskService.updateTask(
            taskId: int.parse(widget.task!['task_id'].toString()),
            title: _titleCtrl.text,
            description: _descCtrl.text,
            priority: priority,
            deadline: finalDeadline.toIso8601String(),
            categoryId: selectedCategoryId,
            showDailyUntilDone: showDailyUntilDone,
            recurrenceType: recurrenceType,
            recurrenceDays: recurrenceType == 'weekly'
                ? weeklyDays.join(',')
                : null,

            // 🔥 ADD THESE
            taskType: assignType,
            assignees: assignType == 'SELF'
                ? [userId!]
                : selectedParticipants
                    .where((u) => u['role'] == 'DOER')
                    .map((u) => u['id'] as int)
                    .toList(),
            watchers: selectedParticipants
                .where((u) => u['role'] == 'VIEWER')
                .map((u) => u['id'] as int)
                .toList(),
            )
          : await TaskService.createTask(
              title: _titleCtrl.text,
              description: _descCtrl.text,
              taskType: assignType,
              priority: priority,

              recurrenceType: recurrenceType,
              recurrenceDays: recurrenceType == 'weekly'
                  ? weeklyDays.join(',')
                  : null,

              projectId: null,

              assignees: assignType == 'SELF'
                  ? [userId!]
                  : selectedParticipants
                      .where((u) => u['role'] == 'DOER')
                      .map((u) => u['id'] as int)
                      .toList(),

              watchers: selectedParticipants
                  .where((u) => u['role'] == 'VIEWER')
                  .map((u) => u['id'] as int)
                  .toList(),

              
              deadline: finalDeadline.toIso8601String(),
              createdBy: userId!,
              categoryId: selectedCategoryId,
              showDailyUntilDone: showDailyUntilDone,
          );
        
    

    setState(() => loading = false);

    if (result['success'] == true) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'] ?? 'Failed')),
      );
    }
  }

@override
void dispose() {
  _titleCtrl.dispose();
  _descCtrl.dispose();
  super.dispose();
}


Widget _roleChip(int userId, String role) {
  final user = selectedParticipants
      .firstWhere((u) => u['id'] == userId, orElse: () => {});

  final selected = user.isNotEmpty && user['role'] == role;

  return GestureDetector(
    onTap: () {
      setState(() {
        final index = selectedParticipants
            .indexWhere((u) => u['id'] == userId);

        if (index != -1) {
          selectedParticipants[index]['role'] = role;
        }
      });
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? Colors.green : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role,
        style: TextStyle(
          color: selected ? Colors.white : Colors.black,
          fontSize: 12,
        ),
      ),
    ),
  );
}

Widget _compactRoleChip(int userId, String role) {
  final user = selectedParticipants
      .firstWhere((u) => u['id'] == userId, orElse: () => {});

  final selected = user.isNotEmpty && user['role'] == role;

  return GestureDetector(
    onTap: () {
      setState(() {
        final index = selectedParticipants
            .indexWhere((u) => u['id'] == userId);

        if (index != -1) {
          selectedParticipants[index]['role'] = role;
        }
      });
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: selected ? Colors.green : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role,
        style: TextStyle(
          color: selected ? Colors.white : Colors.black,
          fontSize: 11,
        ),
      ),
    ),
  );
}




Widget _recurrenceChip(String value, String label) {
  final selected = recurrenceType == value;

  return Padding(
    padding: const EdgeInsets.only(right: 6),
    child: GestureDetector(
      onTap: () {
        setState(() {
          recurrenceType = value;

          // ✅ Clear weekly selection if switching away
          if (value != 'weekly') {
            weeklyDays.clear();
          }

        });
      },      
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.green : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black,
            fontSize: 12,
          ),
        ),
      ),
    ),
  );
}



  @override
  Widget build(BuildContext context) {



    return Scaffold(

      appBar: AppBar(
        title: Text(
          widget.isEdit ? 'Edit Task' : 'Create Task',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),        
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,        
        
      ),
      

      
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [


Card(
  elevation: 0,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
    side: BorderSide(color: Colors.grey.shade300),
  ),
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Row(
      children: [
        // 🔽 CATEGORY DROPDOWN (TextField-like)
        Expanded(
          child: DropdownButtonFormField<int>(
            value: selectedCategoryId,
            items: categories.isEmpty
                ? []
                : categories.map((c) {
                    return DropdownMenuItem<int>(
                      value: c['id'],
                      child: Text(c['category_name']),
                    );
                  }).toList(),
            onChanged: categories.isEmpty
                ? null
                : (value) {
                    setState(() {
                      selectedCategoryId = value;
                    });
                  },
            decoration: InputDecoration(
              hintText: 'Category',
              border: InputBorder.none, // 🔥 important
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: true,
              fillColor: Colors.white, // exact match
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 16,
              ),
            ),
            icon: const Icon(Icons.keyboard_arrow_down),
          ),
        ),

        // ➕ PLUS ICON
        IconButton(
          icon: const Icon(Icons.add),
          splashRadius: 20,
          tooltip: 'Manage categories',
          onPressed: () async {
            final updated = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CategoryManagementScreen(),
              ),
            );

            if (updated == true) {
              _loadCategories();
            }
          },
        ),
      ],
    ),
  ),
),
            

            const SizedBox(height: 12),
            

              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Task title',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),

            
            const SizedBox(height: 12),
            
if (!showDescription)
  Align(
    alignment: Alignment.centerLeft,
    child: TextButton(
      onPressed: () {
        setState(() => showDescription = true);
      },
      child: const Text('+ Add description (optional)'),
    ),
  )
else
  Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: Colors.grey.shade300),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: TextField(
        controller: _descCtrl,
        maxLines: 2,
        decoration: const InputDecoration(
          hintText: 'Description (optional)',
          border: InputBorder.none,
        ),
      ),
    ),
  ),


            const SizedBox(height: 16),


            // 🔥 ASSIGN SECTION (new clean block)

            
// ================= ASSIGN SECTION =================

if (approvedParticipants.isNotEmpty) ...[
  Align(
    alignment: Alignment.centerLeft,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Assign To',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),

        ToggleButtons(
          borderRadius: BorderRadius.circular(14),
          selectedColor: Colors.white,
          fillColor: Colors.green,
          color: Colors.black,
          isSelected: [
            assignType == 'SELF',
            assignType == 'PARTICIPANTS',
          ],
          onPressed: (index) {
            setState(() {
              assignType =
                  index == 0 ? 'SELF' : 'PARTICIPANTS';
            });
          },
          children: const [
            SizedBox(
              width: 120,
              child: Center(child: Text('Myself')),
            ),
            SizedBox(
              width: 120,
              child: Center(child: Text('Participants')),
            ),
          ],
        ),
      ],
    ),
  ),

  const SizedBox(height: 12),

if (assignType == 'PARTICIPANTS')
  Column(
    children: approvedParticipants.map((user) {
      final selected = selectedParticipants
          .any((u) => u['id'] == user['id']);

      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    selectedParticipants.add({
                      'id': user['id'],
                      'full_name': user['full_name'],
                      'role': 'DOER',
                    });
                  } else {
                    selectedParticipants.removeWhere(
                        (u) => u['id'] == user['id']);
                  }
                });
              },
            ),

            Expanded(
              child: Text(
                user['full_name'],
                style: const TextStyle(fontSize: 14),
              ),
            ),

            if (selected) ...[
              _compactRoleChip(user['id'], 'DOER'),
              const SizedBox(width: 6),
              _compactRoleChip(user['id'], 'VIEWER'),
            ],
          ],
        ),
      );
    }).toList(),
  ),
  
    

  const SizedBox(height: 20),
],

// ================= END ASSIGN SECTION =================



            const SizedBox(height: 20), // 👈 ADD THIS


            DropdownButtonFormField(
              value: priority,
              items: const [
                DropdownMenuItem(value: 'LOW', child: Text('Low')),
                DropdownMenuItem(value: 'NORMAL', child: Text('Normal')),
                DropdownMenuItem(value: 'URGENT', child: Text('Urgent')),
              ],
              onChanged: (v) => setState(() => priority = v!),
              decoration: InputDecoration(
                labelText: 'Priority',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              
            ),

            const SizedBox(height: 16),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Deadline',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500, // 👈 same as Priority label
                      color: Colors.black87,
                    ),
                  ),
                ),
                

                const SizedBox(height: 8),

                // 🔹 Deadline Type Selector (modern replacement for radio)
              
Align(
  alignment: Alignment.centerLeft,
  child: ToggleButtons(
    isSelected: [
      deadlineType == 'IMMEDIATE',
      deadlineType == 'DATE',
    ],
    borderRadius: BorderRadius.circular(14),
    selectedColor: Colors.white,
    fillColor: Colors.green,
    color: Colors.black,
    onPressed: (index) {
      setState(() {
        deadlineType = index == 0 ? 'IMMEDIATE' : 'DATE';
        selectedDeadline =
            deadlineType == 'IMMEDIATE' ? DateTime.now() : null;
      });
    },
    children: const [
      SizedBox(
        width: 130,
        child: Center(child: Text('Immediate')),
      ),
      SizedBox(
        width: 130,
        child: Center(child: Text('Select Date')),
      ),
    ],
  ),
),



                
                

                const SizedBox(height: 12),

                // 🔹 Date picker tile (only when DATE)
                if (deadlineType == 'DATE')
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    leading: const Icon(Icons.calendar_today),
                    title: Text(
                      selectedDeadline == null
                          ? 'Set deadline'
                          : DateFormat('dd MMM yyyy, hh:mm a')
                              .format(selectedDeadline!),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickDeadline,
                  ),
              ],
            ),


            const SizedBox(height: 16),

            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    const Text(
                      'Recurrence',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // 🔁 Type Toggle
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _recurrenceChip('none', 'One Time'),
                          _recurrenceChip('daily', 'Daily'),
                          _recurrenceChip('weekly', 'Weekly'),
                          _recurrenceChip('monthly', 'Monthly'),
                          _recurrenceChip('yearly', 'Yearly'),
                        ],
                      ),
                    ),
                    

                    // 📅 WEEKLY OPTIONS
                    if (recurrenceType == 'weekly') ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        children: List.generate(7, (index) {
                          final day = index + 1;
                          final labels = ['M','T','W','T','F','S','S'];
                          final selected = weeklyDays.contains(day);


                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (weeklyDays.contains(day)) {
                                  weeklyDays.remove(day);
                                } else {
                                  weeklyDays.add(day);
                                }
                              });
                            },                            
                            child: Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.green
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                labels[index],
                                style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : Colors.black,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],

                    // 🗓 MONTHLY OPTION
                    if (recurrenceType == 'monthly') ...[
                      const SizedBox(height: 12),
                      Text(
                        'Repeats on day ${selectedDeadline?.day ?? DateTime.now().day}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],

                    // 🎉 YEARLY OPTION
                    if (recurrenceType == 'yearly') ...[
                      const SizedBox(height: 12),
                      Text(
                        'Repeats every year on selected date',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  d(widget.isEdit ? 'Update Task button CLICKED' : 'Create Task button CLICKED');
                  _submit();
                },
                child: Text(
                  widget.isEdit ? 'Update Task' : 'Create Task',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                
              ),
            ),
            
            
          ],
        ),
      ),
    );
  }
}

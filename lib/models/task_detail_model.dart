class TaskDetailModel {
  final Map<String, dynamic> task;
  final List<dynamic> participants;
  final List<dynamic> milestones;
  final List<dynamic> completionHistory;

  TaskDetailModel({
    required this.task,
    required this.participants,
    required this.milestones,
    required this.completionHistory,
  });

  factory TaskDetailModel.fromJson(Map<String, dynamic> json) {
    return TaskDetailModel(
      task: json['task'] ?? {},
      participants: json['participants'] ?? [],
      milestones: json['milestones'] ?? [],
      completionHistory: json['completion_history'] ?? [],
    );
  }
}
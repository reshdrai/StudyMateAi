import 'task_item.dart';
import 'ai_tip.dart';

class HomeSummary {
  final String userName;
  final int completedTasks;
  final int totalTasks;
  final String progressText; // "66% Done"
  final TaskItem nextTask;
  final AiTip aiTip;

  HomeSummary({
    required this.userName,
    required this.completedTasks,
    required this.totalTasks,
    required this.progressText,
    required this.nextTask,
    required this.aiTip,
  });

  factory HomeSummary.fromJson(Map<String, dynamic> json) => HomeSummary(
    userName: json["userName"] ?? "Student",
    completedTasks: json["completedTasks"] ?? 0,
    totalTasks: json["totalTasks"] ?? 0,
    progressText: json["progressText"] ?? "0% Done",
    nextTask: TaskItem.fromJson(json["nextTask"] ?? {}),
    aiTip: AiTip.fromJson(json["aiTip"] ?? {}),
  );
}

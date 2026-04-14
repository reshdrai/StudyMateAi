import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/token_storage.dart';
import '../../../services/api_config.dart';

class StudyPlanRepository {
  String get baseUrl => ApiConfig.baseUrl;

  Future<Map<String, String>> _headers() async {
    final token = await TokenStorage.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<StudyPlanData> generatePlan(int materialId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/materials/$materialId/study-plan/generate'),
      headers: await _headers(),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return StudyPlanData.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to generate study plan: ${res.body}');
  }

  Future<StudyPlanData> getPlan(int materialId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/materials/$materialId/study-plan'),
      headers: await _headers(),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return StudyPlanData.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to load plan: ${res.body}');
  }

  Future<StudyPlanData> reschedule(int materialId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/materials/$materialId/study-plan/reschedule'),
      headers: await _headers(),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return StudyPlanData.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to reschedule: ${res.body}');
  }

  Future<void> toggleTask(int taskId, bool completed) async {
    await http.patch(
      Uri.parse('$baseUrl/api/materials/study-plan/tasks/$taskId'),
      headers: await _headers(),
      body: jsonEncode({'completed': completed}),
    );
  }
}

// ═══════════ Models ═══════════

class StudyPlanData {
  final int materialId;
  final List<PlanDay> days;
  final bool hasPlan;

  StudyPlanData({
    required this.materialId,
    required this.days,
    required this.hasPlan,
  });

  factory StudyPlanData.fromJson(Map<String, dynamic> json) {
    return StudyPlanData(
      materialId: json['materialId'] ?? 0,
      days: (json['days'] as List? ?? [])
          .map((d) => PlanDay.fromJson(d))
          .toList(),
      hasPlan: json['hasPlan'] ?? false,
    );
  }

  int get totalTasks => days.fold(0, (s, d) => s + d.tasks.length);
  int get completedTasks =>
      days.fold(0, (s, d) => s + d.tasks.where((t) => t.completed).length);
  int get totalMinutes => days.fold(0, (s, d) => s + d.totalMinutes);
}

class PlanDay {
  final String label;
  final String date;
  final List<PlanTask> tasks;
  final int totalMinutes;

  PlanDay({
    required this.label,
    required this.date,
    required this.tasks,
    required this.totalMinutes,
  });

  bool get allCompleted => tasks.isNotEmpty && tasks.every((t) => t.completed);
  int get completedCount => tasks.where((t) => t.completed).length;

  factory PlanDay.fromJson(Map<String, dynamic> json) {
    return PlanDay(
      label: json['day'] ?? '',
      date: json['date'] ?? '',
      tasks: (json['tasks'] as List? ?? [])
          .map((t) => PlanTask.fromJson(t))
          .toList(),
      totalMinutes: json['totalMinutes'] ?? 0,
    );
  }
}

class PlanTask {
  final int id;
  final String title;
  final String description;
  final String topicLabel;
  final String priority;
  final int estimatedMinutes;
  final String taskType;
  bool completed;

  PlanTask({
    required this.id,
    required this.title,
    required this.description,
    required this.topicLabel,
    required this.priority,
    required this.estimatedMinutes,
    required this.taskType,
    required this.completed,
  });

  bool get isRescheduled => taskType == 'RESCHEDULED';

  factory PlanTask.fromJson(Map<String, dynamic> json) {
    return PlanTask(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      topicLabel: json['topicLabel'] ?? '',
      priority: json['priority'] ?? 'MEDIUM',
      estimatedMinutes: json['estimatedMinutes'] ?? 25,
      taskType: json['taskType'] ?? 'READ',
      completed: json['completed'] ?? false,
    );
  }
}

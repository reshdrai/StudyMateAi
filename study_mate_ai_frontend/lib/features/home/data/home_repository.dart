import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/token_storage.dart';
import '../../../services/api_config.dart';

class UpcomingTask {
  final int id;
  final String title;
  final String description;
  final String subjectTag;
  final String timeLabel;
  final int? materialId;
  final String taskType;

  UpcomingTask({
    required this.id,
    required this.title,
    required this.description,
    required this.subjectTag,
    required this.timeLabel,
    this.materialId,
    this.taskType = 'READ',
  });

  factory UpcomingTask.fromJson(Map<String, dynamic> json) {
    return UpcomingTask(
      id: (json['id'] ?? 0) as int,
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      subjectTag: (json['subjectTag'] ?? 'STUDY').toString(),
      timeLabel: (json['timeLabel'] ?? '').toString(),
      materialId: json['materialId'] as int?,
      taskType: (json['taskType'] ?? 'READ').toString(),
    );
  }
}

class HomeSummary {
  final String userName;
  final int completedTasks;
  final int totalTasks;
  final String progressText;
  final UpcomingTask? nextTask;
  final List<UpcomingTask> upcomingTasks;
  final String aiTip;

  HomeSummary({
    required this.userName,
    required this.completedTasks,
    required this.totalTasks,
    required this.progressText,
    this.nextTask,
    this.upcomingTasks = const [],
    required this.aiTip,
  });

  double get progressRatio =>
      totalTasks == 0 ? 0.0 : (completedTasks / totalTasks).clamp(0.0, 1.0);

  factory HomeSummary.fromJson(Map<String, dynamic> json) {
    final nextTaskJson = json['nextTask'] as Map<String, dynamic>?;
    final upcomingJson = (json['upcomingTasks'] as List?) ?? [];
    final aiTipJson = json['aiTip'] as Map<String, dynamic>?;

    return HomeSummary(
      userName: (json['userName'] ?? 'Student').toString(),
      completedTasks: (json['completedTasks'] ?? 0) as int,
      totalTasks: (json['totalTasks'] ?? 0) as int,
      progressText: (json['progressText'] ?? '0% Done').toString(),
      nextTask: nextTaskJson != null
          ? UpcomingTask.fromJson(nextTaskJson)
          : null,
      upcomingTasks: upcomingJson
          .map((e) => UpcomingTask.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      aiTip: aiTipJson != null ? (aiTipJson['message'] ?? '').toString() : '',
    );
  }

  static HomeSummary get fallback => HomeSummary(
    userName: 'Student',
    completedTasks: 0,
    totalTasks: 0,
    progressText: '0% Done',
    nextTask: UpcomingTask(
      id: 0,
      title: 'No upcoming task',
      description: 'Start by uploading notes and generating a study plan.',
      subjectTag: 'GENERAL',
      timeLabel: '',
    ),
    upcomingTasks: const [],
    aiTip: 'Upload notes or create a study plan to get personalized tips.',
  );
}

class HomeRepository {
  String get _baseUrl => '${ApiConfig.baseUrl}/api/home';

  Future<Map<String, String>> _headers() async {
    final token = await TokenStorage.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<HomeSummary> getHomeSummary() async {
    final res = await http
        .get(Uri.parse('$_baseUrl/summary'), headers: await _headers())
        .timeout(const Duration(seconds: 15));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return HomeSummary.fromJson(jsonDecode(res.body));
    }
    throw Exception('Home summary failed: ${res.statusCode}');
  }
}

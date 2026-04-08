class HomeSummary {
  final String userName;
  final int completedTasks;
  final int totalTasks;
  final String progressText;
  final NextTask nextTask;
  final AiTip aiTip;

  HomeSummary({
    required this.userName,
    required this.completedTasks,
    required this.totalTasks,
    required this.progressText,
    required this.nextTask,
    required this.aiTip,
  });

  factory HomeSummary.fromJson(Map<String, dynamic> json) {
    return HomeSummary(
      userName: json['userName'] ?? 'Student',
      completedTasks: json['completedTasks'] ?? 0,
      totalTasks: json['totalTasks'] ?? 0,
      progressText: json['progressText'] ?? '0% Done',
      nextTask: NextTask.fromJson(json['nextTask'] ?? {}),
      aiTip: AiTip.fromJson(json['aiTip'] ?? {}),
    );
  }

  factory HomeSummary.fallback() {
    return HomeSummary(
      userName: 'Student',
      completedTasks: 0,
      totalTasks: 0,
      progressText: '0% Done',
      nextTask: NextTask(
        id: 0,
        subjectTag: 'GENERAL',
        title: 'No upcoming task',
        timeLabel: '',
        description: 'Start by adding a goal or uploading notes.',
      ),
      aiTip: AiTip(
        message: 'Upload notes or create goals to get personalized study tips.',
      ),
    );
  }
}

class NextTask {
  final int id;
  final String subjectTag;
  final String title;
  final String timeLabel;
  final String description;

  NextTask({
    required this.id,
    required this.subjectTag,
    required this.title,
    required this.timeLabel,
    required this.description,
  });

  factory NextTask.fromJson(Map<String, dynamic> json) {
    return NextTask(
      id: json['id'] ?? 0,
      subjectTag: json['subjectTag'] ?? 'GENERAL',
      title: json['title'] ?? 'No upcoming task',
      timeLabel: json['timeLabel'] ?? '',
      description:
          json['description'] ?? 'Start by adding a goal or uploading notes.',
    );
  }
}

class AiTip {
  final String message;

  AiTip({required this.message});

  factory AiTip.fromJson(Map<String, dynamic> json) {
    return AiTip(
      message:
          json['message'] ??
          'Upload notes or create goals to get personalized study tips.',
    );
  }
}

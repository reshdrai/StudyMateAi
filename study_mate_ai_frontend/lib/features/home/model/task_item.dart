class TaskItem {
  final String id;
  final String subjectTag; // "ECONOMICS 101"
  final String title; // "Macroeconomics: Ch. 4 Review"
  final String timeLabel; // "15:00 - 16:00 (60 min)"
  final String description;
  final int durationMinutes;

  TaskItem({
    required this.id,
    required this.subjectTag,
    required this.title,
    required this.timeLabel,
    required this.description,
    required this.durationMinutes,
  });

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
    id: json["id"] ?? "",
    subjectTag: json["subjectTag"] ?? "",
    title: json["title"] ?? "",
    timeLabel: json["timeLabel"] ?? "",
    description: json["description"] ?? "",
    durationMinutes: json["durationMinutes"] ?? 0,
  );
}

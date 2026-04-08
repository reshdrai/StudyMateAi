class FlashcardItem {
  final String front;
  final String back;

  FlashcardItem({required this.front, required this.back});

  factory FlashcardItem.fromJson(Map<String, dynamic> json) {
    return FlashcardItem(front: json['front'] ?? '', back: json['back'] ?? '');
  }
}

class TopicPriorityItem {
  final String topic;
  final String priority;
  final double? score;
  final List<String> subtopics;

  TopicPriorityItem({
    required this.topic,
    required this.priority,
    required this.score,
    required this.subtopics,
  });

  factory TopicPriorityItem.fromJson(Map<String, dynamic> json) {
    return TopicPriorityItem(
      topic: json['topic'] ?? '',
      priority: json['priority'] ?? 'MEDIUM',
      score: json['score'] == null ? null : (json['score'] as num).toDouble(),
      subtopics: (json['subtopics'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class QuizQuestionItem {
  final String question;
  final String answer;
  final String topic;
  final List<String> options;

  QuizQuestionItem({
    required this.question,
    required this.answer,
    required this.topic,
    required this.options,
  });

  factory QuizQuestionItem.fromJson(Map<String, dynamic> json) {
    return QuizQuestionItem(
      question: json['question'] ?? '',
      answer: json['answer'] ?? '',
      topic: json['topic'] ?? 'General',
      options: (json['options'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class OverviewResponse {
  final int materialId;
  final List<FlashcardItem> flashcards;
  final List<TopicPriorityItem> importantTopics;

  OverviewResponse({
    required this.materialId,
    required this.flashcards,
    required this.importantTopics,
  });

  factory OverviewResponse.fromJson(Map<String, dynamic> json) {
    return OverviewResponse(
      materialId: json['materialId'],
      flashcards: (json['flashcards'] as List<dynamic>? ?? [])
          .map((e) => FlashcardItem.fromJson(e))
          .toList(),
      importantTopics: (json['importantTopics'] as List<dynamic>? ?? [])
          .map((e) => TopicPriorityItem.fromJson(e))
          .toList(),
    );
  }
}

class QuizResponse {
  final int materialId;
  final List<QuizQuestionItem> questions;

  QuizResponse({required this.materialId, required this.questions});

  factory QuizResponse.fromJson(Map<String, dynamic> json) {
    return QuizResponse(
      materialId: json['materialId'],
      questions: (json['questions'] as List<dynamic>? ?? [])
          .map((e) => QuizQuestionItem.fromJson(e))
          .toList(),
    );
  }
}

class QuizResult {
  final int totalQuestions;
  final int correctAnswers;
  final double scorePercent;
  final List<String> weakTopics;

  QuizResult({
    required this.totalQuestions,
    required this.correctAnswers,
    required this.scorePercent,
    required this.weakTopics,
  });

  factory QuizResult.fromJson(Map<String, dynamic> json) {
    return QuizResult(
      totalQuestions: json['totalQuestions'] ?? 0,
      correctAnswers: json['correctAnswers'] ?? 0,
      scorePercent: (json['scorePercent'] as num?)?.toDouble() ?? 0,
      weakTopics: (json['weakTopics'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class StudyPlanDay {
  final String day;
  final List<String> tasks;

  StudyPlanDay({required this.day, required this.tasks});

  factory StudyPlanDay.fromJson(Map<String, dynamic> json) {
    return StudyPlanDay(
      day: json['day'] ?? '',
      tasks: (json['tasks'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class StudyPlanResponse {
  final int materialId;
  final List<StudyPlanDay> days;

  StudyPlanResponse({required this.materialId, required this.days});

  factory StudyPlanResponse.fromJson(Map<String, dynamic> json) {
    return StudyPlanResponse(
      materialId: json['materialId'],
      days: (json['days'] as List<dynamic>? ?? [])
          .map((e) => StudyPlanDay.fromJson(e))
          .toList(),
    );
  }
}

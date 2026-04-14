import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/token_storage.dart';
import '../../../services/api_config.dart';
import 'study_models.dart';

class StudyAiRepository {
  String get baseUrl => '${ApiConfig.baseUrl}/api/materials';

  Future<Map<String, String>> _headers() async {
    final token = await TokenStorage.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<OverviewResponse> generateOverview(int materialId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/$materialId/overview'),
      headers: await _headers(),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return OverviewResponse.fromJson(jsonDecode(res.body));
    }
    throw Exception('Overview failed: ${res.body}');
  }

  /// Generate quiz for ALL topics
  Future<QuizResponse> generateQuiz(int materialId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/$materialId/quiz'),
      headers: await _headers(),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return QuizResponse.fromJson(jsonDecode(res.body));
    }
    throw Exception('Quiz failed: ${res.body}');
  }

  /// Generate quiz for a SPECIFIC topic
  Future<QuizResponse> generateQuizForTopic(
    int materialId,
    String topicLabel, {
    int maxQuestions = 5,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/$materialId/quiz/topic'),
      headers: await _headers(),
      body: jsonEncode({
        'topicLabel': topicLabel,
        'maxQuestions': maxQuestions,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return QuizResponse.fromJson(jsonDecode(res.body));
    }
    throw Exception('Quiz failed: ${res.body}');
  }

  Future<QuizResult> submitQuiz(
    int materialId,
    Map<String, String> answers,
  ) async {
    final body = {
      'answers': answers.entries
          .map((e) => {'question': e.key, 'userAnswer': e.value})
          .toList(),
    };
    final res = await http.post(
      Uri.parse('$baseUrl/$materialId/quiz/submit'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return QuizResult.fromJson(jsonDecode(res.body));
    }
    throw Exception('Submit failed: ${res.body}');
  }

  Future<dynamic> generateStudyPlan(int materialId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/$materialId/study-plan'),
      headers: await _headers(),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body);
    }
    throw Exception('Study plan failed: ${res.body}');
  }
}

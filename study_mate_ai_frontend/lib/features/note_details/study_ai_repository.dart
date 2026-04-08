import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/token_storage.dart';
import 'study_models.dart';

class StudyAiRepository {
  final baseUrl = 'http://localhost:8080/api/materials';

  Future<Map<String, String>> _headers() async {
    final token = await TokenStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<OverviewResponse> generateOverview(int materialId) async {
    final url = Uri.parse('$baseUrl/$materialId/overview');
    print('OVERVIEW URL: $url');

    final response = await http.post(url, headers: await _headers());

    print('OVERVIEW STATUS: ${response.statusCode}');
    print('OVERVIEW BODY: ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return OverviewResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Overview failed: ${response.body}');
    }
  }

  Future<QuizResponse> generateQuiz(int materialId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/$materialId/quiz'),
      headers: await _headers(),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return QuizResponse.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to generate quiz: ${res.body}');
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
    throw Exception('Failed to submit quiz: ${res.body}');
  }

  Future<StudyPlanResponse> generateStudyPlan(int materialId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/$materialId/study-plan'),
      headers: await _headers(),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return StudyPlanResponse.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to generate study plan: ${res.body}');
  }
}

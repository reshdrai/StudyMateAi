import 'dart:convert';
import 'package:http/http.dart' as http;

import '../model/home_summary.dart';
import '../../../services/token_storage.dart';
import '../../../services/api_config.dart';

class HomeRepository {
  String get baseUrl => ApiConfig.baseUrl;

  Future<HomeSummary> getHomeSummary() async {
    try {
      final token = await TokenStorage.getToken();

      print("========== HOME API CALL ==========");
      print("BASE URL: $baseUrl");
      print("TOKEN: $token");

      final response = await http
          .get(
            Uri.parse('$baseUrl/api/home/summary'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null && token.isNotEmpty)
                'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      print("STATUS CODE: ${response.statusCode}");
      print("RESPONSE BODY: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return HomeSummary.fromJson(decoded);
        }
        return HomeSummary.fallback();
      }

      if (response.statusCode == 401) {
        print("ERROR: Unauthorized - token missing or invalid");
        return HomeSummary.fallback();
      }

      return HomeSummary.fallback();
    } catch (e) {
      print("EXCEPTION IN HOME API: $e");
      return HomeSummary.fallback();
    }
  }
}

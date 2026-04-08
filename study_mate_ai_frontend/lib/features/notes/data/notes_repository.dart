import 'dart:convert';
import 'package:http/http.dart' as http;

import '../model/note_item.dart';
import '../../../services/token_storage.dart';
import '../../../services/api_config.dart';

class NotesRepository {
  String get baseUrl => ApiConfig.baseUrl;
  // change to your laptop IP if using real device

  Future<List<NoteItem>> getNotes({
    required String category,
    required String query,
  }) async {
    try {
      final token = await TokenStorage.getToken();

      final uri = Uri.parse(
        '$baseUrl/api/materials',
      ).replace(queryParameters: {'category': category, 'q': query});

      final response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              if (token != null && token.isNotEmpty)
                'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      print('NOTES STATUS: ${response.statusCode}');
      print('NOTES BODY: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded
              .map((e) => NoteItem.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }

      return [];
    } catch (e) {
      print('NOTES ERROR: $e');
      return [];
    }
  }
}

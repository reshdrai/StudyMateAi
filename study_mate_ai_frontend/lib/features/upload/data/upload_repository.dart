import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/api_config.dart';
import '../../../services/token_storage.dart';

class UploadRepository {
  String get baseUrl => ApiConfig.baseUrl;

  Future<String> uploadStudyMaterial({
    required List<int> fileBytes,
    required String fileName,
    required String title,
    required String? subjectId,
  }) async {
    final token = await TokenStorage.getToken();

    print("========== UPLOAD API CALL ==========");
    print("TOKEN: $token");
    print("FILE NAME: $fileName");
    print("TITLE: $title");
    print("SUBJECT ID: $subjectId");

    if (token == null || token.isEmpty) {
      return "User not logged in (token missing)";
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/materials/upload'),
    );

    request.headers['Authorization'] = 'Bearer $token';

    request.files.add(
      http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
    );

    request.fields['title'] = title;

    if (subjectId != null) {
      request.fields['subjectId'] = subjectId;
    }

    try {
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      print("UPLOAD STATUS: ${response.statusCode}");
      print("UPLOAD BODY: ${response.body}");

      if (response.statusCode == 200) {
        return "Upload success";
      } else {
        return "Upload failed: ${response.body}";
      }
    } catch (e) {
      print("UPLOAD ERROR: $e");
      return "Upload failed: $e";
    }
  }
}

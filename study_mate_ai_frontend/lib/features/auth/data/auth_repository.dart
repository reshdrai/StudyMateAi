import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../../../services/api_config.dart';
import '../../../services/token_storage.dart';

class AuthRepository {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String get baseUrl => ApiConfig.baseUrl;

  Future<void> login({required String email, required String password}) async {
    if (email.trim().isEmpty || password.trim().isEmpty) {
      throw Exception("Please enter email and password");
    }

    final response = await http.post(
      Uri.parse("$baseUrl/auth/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email.trim(), "password": password}),
    );

    print("LOGIN STATUS: ${response.statusCode}");
    print("LOGIN BODY: ${response.body}");

    if (response.body.trim().isEmpty) {
      throw Exception(
        "Server returned empty response (${response.statusCode})",
      );
    }

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      final token = data["token"];

      if (token == null || token.toString().isEmpty) {
        throw Exception("Token not found in login response");
      }

      await TokenStorage.saveAuthData(
        token: token.toString(),
        email: (data["email"] ?? "").toString(),
        name: (data["name"] ?? "").toString(),
        role: (data["role"] ?? "").toString(),
      );

      await _storage.write(
        key: "userEmail",
        value: (data["email"] ?? "").toString(),
      );
      await _storage.write(
        key: "userName",
        value: (data["name"] ?? "").toString(),
      );
      await _storage.write(
        key: "userRole",
        value: (data["role"] ?? "").toString(),
      );
    } else {
      throw Exception(data["message"] ?? data["detail"] ?? data.toString());
    }
  }

  Future<void> signup({
    required String fullName,
    required String email,
    required String password,
  }) async {
    if (fullName.trim().isEmpty ||
        email.trim().isEmpty ||
        password.trim().isEmpty) {
      throw Exception("Fill all signup fields");
    }

    final response = await http.post(
      Uri.parse("$baseUrl/auth/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "fullName": fullName.trim(),
        "email": email.trim(),
        "password": password,
      }),
    );

    print("SIGNUP STATUS: ${response.statusCode}");
    print("SIGNUP BODY: ${response.body}");

    if (response.body.trim().isEmpty) {
      throw Exception(
        "Server returned empty response (${response.statusCode})",
      );
    }

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      final token = data["token"];

      if (token == null || token.toString().isEmpty) {
        throw Exception("Token not found in register response");
      }

      await TokenStorage.saveAuthData(
        token: token.toString(),
        email: (data["email"] ?? "").toString(),
        name: (data["name"] ?? "").toString(),
        role: (data["role"] ?? "").toString(),
      );

      await _storage.write(
        key: "userEmail",
        value: (data["email"] ?? "").toString(),
      );
      await _storage.write(
        key: "userName",
        value: (data["name"] ?? "").toString(),
      );
      await _storage.write(
        key: "userRole",
        value: (data["role"] ?? "").toString(),
      );
    } else {
      throw Exception(data["message"] ?? data["detail"] ?? data.toString());
    }
  }

  Future<String?> getToken() async {
    return await TokenStorage.getToken();
  }

  Future<void> forgotPassword({required String email}) async {
    if (email.trim().isEmpty) {
      throw Exception("Enter your email");
    }

    throw Exception("Forgot password API not added yet");
  }

  Future<void> logout() async {
    await TokenStorage.clearAll();
    await _storage.delete(key: "userEmail");
    await _storage.delete(key: "userName");
    await _storage.delete(key: "userRole");
  }
}

import 'package:dio/dio.dart';
import '../../../core/config/env.dart';
import '../model/login_request.dart';
import '../model/login_response.dart';

class AuthApi {
  final Dio _dio;

  AuthApi(this._dio);

  Future<LoginResponse> login(LoginRequest req) async {
    // ✅ WHEN SPRING BOOT API IS READY:
    // 1) Create endpoint in Spring Boot: POST /api/auth/login
    // 2) Return JSON: { "accessToken": "...", "refreshToken": "..." }

    final res = await _dio.post(
      "${Env.apiBaseUrl}/api/auth/login",
      data: req.toJson(),
    );

    return LoginResponse.fromJson(res.data as Map<String, dynamic>);
  }
}

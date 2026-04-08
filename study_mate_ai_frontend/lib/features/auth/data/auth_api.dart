import 'package:dio/dio.dart';
import '../model/login_request.dart';
import '../model/login_response.dart';

class AuthApi {
  final Dio _dio;

  AuthApi(this._dio);

  Future<LoginResponse> login(LoginRequest req) async {
    final res = await _dio.post("/auth/login", data: req.toJson());

    return LoginResponse.fromJson(res.data as Map<String, dynamic>);
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';

import '../../../services/token_storage.dart';
import '../../../services/api_config.dart';

final GoogleSignIn signIn = GoogleSignIn.instance;

Future<Map<String, dynamic>> loginWithGoogle() async {
  await signIn.initialize(
    serverClientId:
        '117487363987-auo2v0brhot4nmlm562qqcsmbatdngp5.apps.googleusercontent.com',
  );

  final GoogleSignInAccount user = await signIn.authenticate();
  final auth = user.authentication;

  final idToken = auth.idToken;
  if (idToken == null) {
    throw Exception('No Google ID token returned');
  }

  final response = await http.post(
    Uri.parse("${ApiConfig.baseUrl}/auth/google"),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'idToken': idToken}),
  );

  if (response.statusCode != 200) {
    throw Exception('Backend login failed: ${response.body}');
  }

  final data = jsonDecode(response.body) as Map<String, dynamic>;

  final token = data['accessToken'] ?? data['token'] ?? data['jwt'];

  if (token == null || token.toString().isEmpty) {
    throw Exception('JWT token not found in backend response');
  }

  await TokenStorage.saveAuthData(
    token: token.toString(),
    email: (data["email"] ?? "").toString(),
    name: (data["name"] ?? "").toString(),
    role: (data["role"] ?? "").toString(),
  );

  print('GOOGLE LOGIN RESPONSE: $data');
  print('TOKEN SAVED: ${await TokenStorage.getToken()}');

  return data;
}

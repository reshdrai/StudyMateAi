class LoginResponse {
  final String token;
  final String email;
  final String name;
  final String role;

  LoginResponse({
    required this.token,
    required this.email,
    required this.name,
    required this.role,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: (json["token"] ?? "").toString(),
      email: (json["email"] ?? "").toString(),
      name: (json["name"] ?? "").toString(),
      role: (json["role"] ?? "").toString(),
    );
  }
}

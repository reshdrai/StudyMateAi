class RegisterResponse {
  final String token;
  final String email;
  final String name;
  final String role;

  RegisterResponse({
    required this.token,
    required this.email,
    required this.name,
    required this.role,
  });

  factory RegisterResponse.fromJson(Map<String, dynamic> json) {
    return RegisterResponse(
      token: (json["token"] ?? "").toString(),
      email: (json["email"] ?? "").toString(),
      name: (json["name"] ?? "").toString(),
      role: (json["role"] ?? "").toString(),
    );
  }
}
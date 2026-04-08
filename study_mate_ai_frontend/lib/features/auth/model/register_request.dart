class RegisterRequest {
  final String fullName;
  final String email;
  final String password;

  RegisterRequest({
    required this.fullName,
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        "fullName": fullName,
        "email": email,
        "password": password,
      };
}
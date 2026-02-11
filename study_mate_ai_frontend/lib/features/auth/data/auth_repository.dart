// import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// class AuthRepository {
//   final FlutterSecureStorage _storage = const FlutterSecureStorage();

//   Future<void> login({required String email, required String password}) async {
//     // ✅ NO-API mode (works now)
//     if (email.isNotEmpty && password.isNotEmpty) {
//       await _storage.write(key: "accessToken", value: "FAKE_ACCESS_TOKEN");
//       await _storage.write(key: "refreshToken", value: "FAKE_REFRESH_TOKEN");
//       return;
//     }
//     throw Exception("Enter email and password");
//   }

//   Future<void> signup({
//     required String fullName,
//     required String email,
//     required String password,
//   }) async {
//     // ✅ NO-API mode (works now)
//     if (fullName.isNotEmpty && email.isNotEmpty && password.isNotEmpty) {
//       // pretend created
//       return;
//     }
//     throw Exception("Fill all signup fields");

//     // ✅ WHEN API IS READY:
//     // POST /api/auth/signup
//     // Body: { fullName, email, password }
//     // return success message or tokens
//   }

//   Future<void> forgotPassword({required String email}) async {
//     // ✅ NO-API mode (works now)
//     if (email.isNotEmpty) {
//       // pretend mail sent
//       return;
//     }
//     throw Exception("Enter email");

//     // ✅ WHEN API IS READY:
//     // POST /api/auth/forgot-password
//     // Body: { email }
//     // return success message
//   }
// }
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthRepository {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> login({required String email, required String password}) async {
    // ✅ NO API MODE (works now)
    if (email.trim().isEmpty || password.trim().isEmpty) {
      throw Exception("Please enter email and password");
    }

    // Fake token store (so future auth guard can work)
    await _storage.write(key: "accessToken", value: "FAKE_ACCESS_TOKEN");
    await _storage.write(key: "refreshToken", value: "FAKE_REFRESH_TOKEN");

    return;

    // ✅ WHEN SPRING BOOT IS READY (UNCOMMENT THIS AND REMOVE FAKE ABOVE):
    // final res = await ApiClient.instance.dio.post("/api/auth/login", data: {
    //   "email": email,
    //   "password": password,
    // });
    // await _storage.write(key: "accessToken", value: res.data["accessToken"]);
    // await _storage.write(key: "refreshToken", value: res.data["refreshToken"]);
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
    return;

    // ✅ LATER: POST /api/auth/signup
  }

  Future<void> forgotPassword({required String email}) async {
    if (email.trim().isEmpty) {
      throw Exception("Enter your email");
    }
    return;

    // ✅ LATER: POST /api/auth/forgot-password
  }
}

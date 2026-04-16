import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/token_storage.dart';
import '../../../services/api_config.dart';

class TrackingItem {
  final int id;
  final String title;
  final String fileType;
  bool isTracked;

  TrackingItem({
    required this.id,
    required this.title,
    required this.fileType,
    required this.isTracked,
  });

  factory TrackingItem.fromJson(Map<String, dynamic> j) => TrackingItem(
    id: j['id'] as int,
    title: j['title'] ?? '',
    fileType: j['fileType'] ?? '',
    isTracked: j['isTracked'] as bool? ?? false,
  );
}

class TrackingRepository {
  String get _base => '${ApiConfig.baseUrl}/api/tracking';

  Future<Map<String, String>> _headers() async {
    final t = await TokenStorage.getToken();
    return {
      'Content-Type': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t',
    };
  }

  Future<List<TrackingItem>> getAll() async {
    final res = await http
        .get(Uri.parse(_base), headers: await _headers())
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list.map((e) => TrackingItem.fromJson(e)).toList();
    }
    throw Exception('Failed to load tracking: ${res.statusCode}');
  }

  Future<bool> toggle(int materialId) async {
    final res = await http
        .post(Uri.parse('$_base/$materialId/toggle'), headers: await _headers())
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['isTracked'] as bool? ?? false;
    }
    throw Exception('Toggle failed: ${res.statusCode}');
  }
}

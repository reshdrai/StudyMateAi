class AiTip {
  final String message;

  AiTip({required this.message});

  factory AiTip.fromJson(Map<String, dynamic> json) =>
      AiTip(message: json["message"] ?? "");
}

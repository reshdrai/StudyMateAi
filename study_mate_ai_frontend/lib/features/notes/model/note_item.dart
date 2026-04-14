enum NoteStatus { aiReady, analyzing, uploaded, none }

enum NoteType { pdf, image, text }

class NoteItem {
  final int id;
  final String title;
  final String dateLabel;
  final NoteType type;
  final String subjectName;
  final NoteStatus status;
  final String? fileUrl;

  NoteItem({
    required this.id,
    required this.title,
    required this.dateLabel,
    required this.type,
    required this.subjectName,
    required this.status,
    this.fileUrl,
  });

  String get typeLabel {
    switch (type) {
      case NoteType.pdf:
        return "PDF";
      case NoteType.image:
        return "Image";
      case NoteType.text:
        return "Text";
    }
  }

  String get metaLabel {
    final left = type == NoteType.image ? "JPG" : typeLabel;
    final sub = subjectName.isNotEmpty ? subjectName : "General";
    return "$left • $sub";
  }

  String get statusLabel {
    switch (status) {
      case NoteStatus.aiReady:
        return "AI READY";
      case NoteStatus.analyzing:
        return "ANALYZING";
      case NoteStatus.uploaded:
        return "UPLOADED";
      case NoteStatus.none:
        return "";
    }
  }

  /// Maps from backend MaterialCardResponse JSON:
  /// {
  ///   "id": 1,
  ///   "title": "Chapter 1",
  ///   "subjectName": "Comp Sci",
  ///   "fileType": "application/pdf",
  ///   "fileUrl": "/uploads/...",
  ///   "createdAt": "2025-04-09T...",
  ///   "processingStatus": "UPLOADED"
  /// }
  factory NoteItem.fromJson(Map<String, dynamic> json) {
    return NoteItem(
      id: _parseInt(json["id"]),
      title: (json["title"] ?? "Untitled").toString(),
      dateLabel: _formatDate(json["createdAt"]),
      type: _typeFromMime(json["fileType"]),
      subjectName: (json["subjectName"] ?? "General").toString(),
      status: _statusFromProcessing(json["processingStatus"]),
      fileUrl: json["fileUrl"]?.toString(),
    );
  }

  static int _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static NoteType _typeFromMime(dynamic v) {
    final s = (v ?? "").toString().toLowerCase();
    if (s.contains("pdf")) return NoteType.pdf;
    if (s.contains("image") || s.contains("jpg") || s.contains("png")) {
      return NoteType.image;
    }
    return NoteType.text;
  }

  static NoteStatus _statusFromProcessing(dynamic v) {
    final s = (v ?? "").toString().toUpperCase();
    if (s.contains("READY") || s.contains("OVERVIEW") || s.contains("QUIZ") || s.contains("PLAN")) {
      return NoteStatus.aiReady;
    }
    if (s.contains("ANALYZING") || s.contains("PROCESSING")) {
      return NoteStatus.analyzing;
    }
    if (s.contains("UPLOADED")) {
      return NoteStatus.uploaded;
    }
    return NoteStatus.none;
  }

  static String _formatDate(dynamic v) {
    if (v == null) return "";
    final s = v.toString();
    // "2025-04-09T14:30:00" -> "Apr 9"
    try {
      final dt = DateTime.parse(s);
      final months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return "${months[dt.month]} ${dt.day}";
    } catch (_) {
      return s.length > 10 ? s.substring(0, 10) : s;
    }
  }
}
enum NoteStatus { aiReady, analyzing, none }

enum NoteType { pdf, image, text }

class NoteItem {
  final String id;
  final String title;
  final String dateLabel; // "Oct 12"
  final NoteType type;
  final String sizeOrKind; // "1.2 MB" or "Image" or "Text"
  final NoteStatus status;
  final String? previewImagePath;

  NoteItem({
    required this.id,
    required this.title,
    required this.dateLabel,
    required this.type,
    required this.sizeOrKind,
    required this.status,
    this.previewImagePath,
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
    // screenshot style: "PDF • 1.2 MB" or "JPG • Image"
    final left = type == NoteType.image ? "JPG" : typeLabel;
    return "$left • $sizeOrKind";
  }

  String get statusLabel {
    switch (status) {
      case NoteStatus.aiReady:
        return "✦ AI READY";
      case NoteStatus.analyzing:
        return "⏳ ANALYZING...";
      case NoteStatus.none:
        return "";
    }
  }

  // Optional for later API usage
  factory NoteItem.fromJson(Map<String, dynamic> json) => NoteItem(
    id: json["id"] ?? "",
    title: json["title"] ?? "",
    dateLabel: json["dateLabel"] ?? "",
    type: _typeFrom(json["type"]),
    sizeOrKind: json["sizeOrKind"] ?? "",
    status: _statusFrom(json["status"]),
    previewImagePath: json["previewImagePath"],
  );

  static NoteType _typeFrom(dynamic v) {
    final s = (v ?? "").toString().toLowerCase();
    if (s == "pdf") return NoteType.pdf;
    if (s == "image") return NoteType.image;
    return NoteType.text;
  }

  static NoteStatus _statusFrom(dynamic v) {
    final s = (v ?? "").toString().toLowerCase();
    if (s == "ai_ready") return NoteStatus.aiReady;
    if (s == "analyzing") return NoteStatus.analyzing;
    return NoteStatus.none;
  }
}

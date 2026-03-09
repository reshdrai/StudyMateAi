import '../model/note_item.dart';

class NotesRepository {
  Future<List<NoteItem>> getNotes({
    required String category,
    required String query,
  }) async {
    // ✅ Works without backend now
    await Future.delayed(const Duration(milliseconds: 250));

    final all = <NoteItem>[
      NoteItem(
        id: "1",
        title: "Data Structures L3",
        dateLabel: "Oct 12",
        type: NoteType.pdf,
        sizeOrKind: "1.2 MB",
        status: NoteStatus.aiReady,
      ),
      NoteItem(
        id: "2",
        title: "Physics Equations",
        dateLabel: "Oct 10",
        type: NoteType.image,
        sizeOrKind: "Image",
        status: NoteStatus.none,
      ),
      NoteItem(
        id: "3",
        title: "History Essay Draft",
        dateLabel: "Oct 08",
        type: NoteType.text,
        sizeOrKind: "Text",
        status: NoteStatus.analyzing,
      ),
      NoteItem(
        id: "4",
        title: "Macroeconomics Notes",
        dateLabel: "Oct 05",
        type: NoteType.pdf,
        sizeOrKind: "0.8 MB",
        status: NoteStatus.aiReady,
      ),
    ];

    // Basic category filter (optional)
    List<NoteItem> filtered = all;
    if (category != "All") {
      final c = category.toLowerCase();
      filtered = all.where((n) => n.title.toLowerCase().contains(c)).toList();
    }

    // Basic search filter
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      filtered = filtered
          .where((n) => n.title.toLowerCase().contains(q))
          .toList();
    }

    return filtered;

    // ✅ WHEN SPRING BOOT IS READY:
    // final res = await ApiClient.instance.dio.get("/api/notes", queryParameters: {
    //   "category": category,
    //   "q": query,
    // });
    // return (res.data as List).map((e) => NoteItem.fromJson(e)).toList();
  }
}

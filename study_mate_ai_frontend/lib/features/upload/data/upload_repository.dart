class UploadRepository {
  Future<String> uploadStudyMaterial() async {
    // ✅ Works without backend now
    await Future.delayed(const Duration(milliseconds: 500));
    return "Uploaded successfully (fake). Later this will extract notes + create quiz.";

    // ✅ WHEN SPRING BOOT IS READY:
    // 1) Pick file using file_picker
    // 2) POST multipart -> /api/materials/upload
    // 3) Response: { materialId, extractedSummary, ... }
  }
}

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'data/upload_repository.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final _repo = UploadRepository();
  bool _loading = false;
  String? _resultText;

  Future<void> _pickAndUpload() async {
    setState(() {
      _loading = true;
      _resultText = null;
    });

    try {
      final res = await _repo.uploadStudyMaterial();
      setState(() => _resultText = res);
    } catch (e) {
      setState(() => _resultText = "Upload failed: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Upload")),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Upload study material",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Upload PDF/Images/Notes. StudyMateAI will extract key points and generate quizzes.",
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _pickAndUpload,
                icon: const Icon(Icons.file_upload_outlined),
                label: _loading
                    ? const Text("Uploading...")
                    : const Text("Pick file & Upload"),
              ),
            ),

            const SizedBox(height: 14),
            if (_resultText != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.outline),
                ),
                child: Text(_resultText!),
              ),

            const Spacer(),
            const Text(
              "API Ready: /api/materials/upload",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

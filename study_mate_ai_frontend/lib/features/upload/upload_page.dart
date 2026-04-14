import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/routes.dart';
import '../../core/theme/app_colors.dart';
import 'data/upload_repository.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final _repo = UploadRepository();

  bool _uploading = false;
  String? _resultText;
  bool _uploadSuccess = false;

  String? _selectedFileName;
  PlatformFile? _pickedFile;

  final TextEditingController _titleController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'txt'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _pickedFile = file;
          _selectedFileName = file.name;
          if (_titleController.text.trim().isEmpty) {
            _titleController.text = _removeExtension(file.name);
          }
          _resultText = null;
          _uploadSuccess = false;
        });
      }
    } catch (e) {
      setState(() => _resultText = 'Failed to pick file: $e');
    }
  }

  Future<void> _upload() async {
    if (_pickedFile == null || _pickedFile!.bytes == null) {
      setState(() => _resultText = "Please pick a file first.");
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _resultText = "Please enter a title.");
      return;
    }

    setState(() {
      _uploading = true;
      _resultText = null;
      _uploadSuccess = false;
    });

    try {
      final res = await _repo.uploadStudyMaterial(
        fileBytes: _pickedFile!.bytes!,
        fileName: _pickedFile!.name,
        title: title,
        subjectId: null,
      );

      final success = !res.toLowerCase().startsWith('upload failed');
      setState(() {
        _resultText = res;
        _uploadSuccess = success;
      });

      if (mounted && success) {
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) context.go(AppRoutes.library);
      }
    } catch (e) {
      setState(() => _resultText = "Upload failed: $e");
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _removeExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1) return fileName;
    return fileName.substring(0, dotIndex);
  }

  IconData _fileIcon() {
    if (_selectedFileName == null) return Icons.cloud_upload_outlined;
    final ext = _selectedFileName!.split('.').last.toLowerCase();
    if (ext == 'pdf') return Icons.picture_as_pdf_outlined;
    if (['jpg', 'jpeg', 'png'].contains(ext)) return Icons.image_outlined;
    return Icons.description_outlined;
  }

  String _fileSize() {
    if (_pickedFile == null) return '';
    final bytes = _pickedFile!.size;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Upload Notes"),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            // ── Drop zone / file picker ──
            GestureDetector(
              onTap: _uploading ? null : _pickFile,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36),
                decoration: BoxDecoration(
                  color: _pickedFile != null
                      ? AppColors.primary.withOpacity(0.04)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _pickedFile != null
                        ? AppColors.primary.withOpacity(0.3)
                        : AppColors.outline,
                    width: _pickedFile != null ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _pickedFile != null
                            ? AppColors.primary.withOpacity(0.12)
                            : AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        _fileIcon(),
                        size: 28,
                        color: _pickedFile != null
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_pickedFile != null) ...[
                      Text(
                        _selectedFileName!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _fileSize(),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Tap to change file',
                        style: TextStyle(
                          color: AppColors.primary.withOpacity(0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ] else ...[
                      const Text(
                        'Tap to select a file',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'PDF, Images, or Text files',
                        style: TextStyle(
                          color: AppColors.textSecondary.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Title input ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Note Title",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _titleController,
                    enabled: !_uploading,
                    decoration: InputDecoration(
                      hintText: "e.g. Chapter 3 - Data Structures",
                      filled: true,
                      fillColor: AppColors.surfaceSoft,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: AppColors.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── What AI will do ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: AppColors.primary.withOpacity(0.12)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI will analyze your notes',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Extract key points, rank topics, and prepare quizzes',
                          style: TextStyle(
                            color: AppColors.textSecondary.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Upload button ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _uploading ? null : _upload,
                icon: _uploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.file_upload_outlined, size: 20),
                label: Text(
                  _uploading ? "Uploading..." : "Upload & Analyze",
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

            // ── Result message ──
            if (_resultText != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _uploadSuccess
                      ? AppColors.success.withOpacity(0.08)
                      : AppColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _uploadSuccess
                        ? AppColors.success.withOpacity(0.2)
                        : AppColors.error.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _uploadSuccess
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      color: _uploadSuccess
                          ? AppColors.success
                          : AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _resultText!,
                        style: TextStyle(
                          color: _uploadSuccess
                              ? AppColors.success
                              : AppColors.error,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

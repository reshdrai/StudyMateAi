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

  bool _loading = false;
  String? _resultText;

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
        });
      }
    } catch (e) {
      setState(() {
        _resultText = 'Failed to pick file: $e';
      });
    }
  }

  Future<void> _upload() async {
    if (_pickedFile == null || _pickedFile!.bytes == null) {
      setState(() {
        _resultText = "Please pick a file first.";
      });
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() {
        _resultText = "Please enter a title.";
      });
      return;
    }

    setState(() {
      _loading = true;
      _resultText = null;
    });

    try {
      final res = await _repo.uploadStudyMaterial(
        fileBytes: _pickedFile!.bytes!,
        fileName: _pickedFile!.name,
        title: title,
        subjectId: null, // later you can pass selected subject id here
      );

      setState(() {
        _resultText = res;
      });

      if (mounted && !res.toLowerCase().startsWith('upload failed')) {
        await Future.delayed(const Duration(milliseconds: 700));
        if (mounted) {
          context.go(AppRoutes.library);
        }
      }
    } catch (e) {
      setState(() {
        _resultText = "Upload failed: $e";
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  String _removeExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1) return fileName;
    return fileName.substring(0, dotIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Upload"),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SingleChildScrollView(
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
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Upload study material",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Upload PDF, images, or text notes. StudyMateAI will summarize them and prepare quiz-ready content.",
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

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
                children: [
                  const Text(
                    "Note Title",
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    enabled: !_loading,
                    decoration: InputDecoration(
                      hintText: "Enter note title",
                      filled: true,
                      fillColor: AppColors.surfaceSoft,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    "Selected File",
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: Text(
                      _selectedFileName ?? "No file selected",
                      style: TextStyle(
                        color: _selectedFileName == null
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _pickFile,
                      icon: const Icon(Icons.attach_file),
                      label: const Text("Pick File"),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _upload,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.file_upload_outlined),
                      label: Text(_loading ? "Uploading..." : "Upload Note"),
                    ),
                  ),
                ],
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

            const SizedBox(height: 20),

            const Text(
              "Backend endpoint: /api/materials/upload",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

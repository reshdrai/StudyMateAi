import 'package:flutter/material.dart';
import './study_ai_repository.dart';
import './study_models.dart';
import '../quiz/quiz_page.dart';

class MaterialStudyPage extends StatefulWidget {
  final int materialId;
  final String title;

  const MaterialStudyPage({
    super.key,
    required this.materialId,
    required this.title,
  });

  @override
  State<MaterialStudyPage> createState() => _MaterialStudyPageState();
}

class _MaterialStudyPageState extends State<MaterialStudyPage> {
  final _repo = StudyAiRepository();

  bool _loading = false;
  OverviewResponse? _overview;

  Future<void> _generateOverview() async {
    setState(() => _loading = true);
    try {
      print("CALLING OVERVIEW FOR ID = ${widget.materialId}");
      final data = await _repo.generateOverview(widget.materialId);
      print("OVERVIEW RESPONSE = $data");

      if (!mounted) return;
      setState(() => _overview = data);
    } catch (e) {
      print("OVERVIEW ERROR = $e");
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      print("OVERVIEW FINISHED");
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _priorityColor(String p) {
    switch (p.toUpperCase()) {
      case 'HIGH':
        return Colors.red;
      case 'MEDIUM':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  void initState() {
    super.initState();
    _generateOverview();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _overview == null
          ? Center(
              child: ElevatedButton(
                onPressed: _generateOverview,
                child: const Text('Generate Overview'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Key Points',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ..._overview!.flashcards.map(
                  (f) => Card(
                    child: ListTile(
                      title: Text(f.front),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(f.back),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Important Topics',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ..._overview!.importantTopics.map(
                  (t) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  t.topic,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _priorityColor(
                                    t.priority,
                                  ).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  t.priority,
                                  style: TextStyle(
                                    color: _priorityColor(t.priority),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (t.subtopics.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: t.subtopics
                                  .map((s) => Chip(label: Text(s)))
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QuizPage(materialId: widget.materialId),
                      ),
                    );
                  },
                  child: const Text('Start Quiz'),
                ),
              ],
            ),
    );
  }
}

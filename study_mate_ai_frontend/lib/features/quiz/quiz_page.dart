import 'package:flutter/material.dart';
import '../note_details/study_ai_repository.dart';
import '../note_details/study_models.dart';
// import '../note_details/materials_study_page.dart';
import '../study_plan/study_plan_page.dart';

class QuizPage extends StatefulWidget {
  final int materialId;

  const QuizPage({super.key, required this.materialId});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final _repo = StudyAiRepository();
  bool _loading = true;
  QuizResponse? _quiz;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    try {
      final data = await _repo.generateQuiz(widget.materialId);
      for (final q in data.questions) {
        _controllers[q.question] = TextEditingController();
      }
      if (!mounted) return;
      setState(() {
        _quiz = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _submitQuiz() async {
    final answers = <String, String>{};
    for (final entry in _controllers.entries) {
      answers[entry.key] = entry.value.text.trim();
    }

    try {
      final result = await _repo.submitQuiz(widget.materialId, answers);
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Quiz Result'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Correct: ${result.correctAnswers}/${result.totalQuestions}',
              ),
              Text('Score: ${result.scorePercent.toStringAsFixed(1)}%'),
              const SizedBox(height: 12),
              const Text(
                'Weak Topics:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...result.weakTopics.map((e) => Text('• $e')),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        StudyPlanPage(materialId: widget.materialId),
                  ),
                );
              },
              child: const Text('Generate Study Plan'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_quiz == null) {
      return const Scaffold(body: Center(child: Text('No quiz found')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ..._quiz!.questions.map(
            (q) => Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q.question,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Topic: ${q.topic}'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _controllers[q.question],
                      decoration: const InputDecoration(
                        hintText: 'Write your answer',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _submitQuiz,
            child: const Text('Submit Quiz'),
          ),
        ],
      ),
    );
  }
}

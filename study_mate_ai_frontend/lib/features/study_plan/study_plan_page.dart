import 'package:flutter/material.dart';
import '../note_details/study_ai_repository.dart';
import '../note_details/study_models.dart';

class StudyPlanPage extends StatefulWidget {
  final int materialId;

  const StudyPlanPage({super.key, required this.materialId});

  @override
  State<StudyPlanPage> createState() => _StudyPlanPageState();
}

class _StudyPlanPageState extends State<StudyPlanPage> {
  final _repo = StudyAiRepository();
  bool _loading = true;
  StudyPlanResponse? _plan;

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    try {
      final data = await _repo.generateStudyPlan(widget.materialId);
      if (!mounted) return;
      setState(() {
        _plan = data;
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_plan == null) {
      return const Scaffold(body: Center(child: Text('No study plan found')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Study Plan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: _plan!.days.map((d) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.day,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...d.tasks.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• $t'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

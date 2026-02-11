import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'data/goals_repository.dart';

class AddGoalPage extends StatefulWidget {
  const AddGoalPage({super.key});

  @override
  State<AddGoalPage> createState() => _AddGoalPageState();
}

class _AddGoalPageState extends State<AddGoalPage> {
  final _repo = GoalsRepository();

  final _title = TextEditingController();
  final _targetTasks = TextEditingController(text: "3");
  bool _loading = false;

  @override
  void dispose() {
    _title.dispose();
    _targetTasks.dispose();
    super.dispose();
  }

  Future<void> _saveGoal() async {
    setState(() => _loading = true);
    try {
      await _repo.createGoal(
        title: _title.text.trim(),
        targetTasksPerDay: int.tryParse(_targetTasks.text.trim()) ?? 3,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Goal saved (UI ready)")));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed: $e")));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Goal")),
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
                    "Create a daily goal",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Example: Finish 3 tasks per day or study 60 minutes daily.",
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: "Goal title",
                hintText: "e.g. Study Economics daily",
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _targetTasks,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Target tasks per day",
                hintText: "e.g. 3",
              ),
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _saveGoal,
                child: _loading
                    ? const Text("Saving...")
                    : const Text("Save Goal"),
              ),
            ),

            const Spacer(),
            const Text(
              "API Ready: POST /api/goals",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

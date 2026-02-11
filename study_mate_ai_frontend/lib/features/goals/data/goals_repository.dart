class GoalsRepository {
  Future<void> createGoal({
    required String title,
    required int targetTasksPerDay,
  }) async {
    // ✅ Works without backend now
    await Future.delayed(const Duration(milliseconds: 350));
    if (title.isEmpty) throw Exception("Goal title is required");

    // ✅ WHEN SPRING BOOT IS READY:
    // POST /api/goals
    // Body: { "title": title, "targetTasksPerDay": targetTasksPerDay }
  }
}

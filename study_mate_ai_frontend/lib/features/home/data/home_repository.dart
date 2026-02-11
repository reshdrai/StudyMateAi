import '../model/home_summary.dart';
import '../model/task_item.dart';
import '../model/ai_tip.dart';

class HomeRepository {
  Future<HomeSummary> getHomeSummary() async {
    // ✅ NO BACKEND NOW: return fake data (works today)
    await Future.delayed(const Duration(milliseconds: 250));

    return HomeSummary(
      userName: "Alex Johnson",
      completedTasks: 4,
      totalTasks: 6,
      progressText: "66% Done",
      nextTask: TaskItem(
        id: "task_1",
        subjectTag: "ECONOMICS 101",
        title: "Macroeconomics: Ch. 4 Review",
        timeLabel: "15:00 - 16:00 (60 min)",
        description: "Focus on supply and demand curves.",
        durationMinutes: 60,
      ),
      aiTip: AiTip(
        message:
            'Based on your recent quizzes, you should spend 15 extra minutes on "Price Elasticity" today to solidify your understanding.',
      ),
    );

    // ✅ WHEN SPRING BOOT IS READY:
    // 1) GET /api/home/summary
    // return await _api.getHomeSummary();
  }
}

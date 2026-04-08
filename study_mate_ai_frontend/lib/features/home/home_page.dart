import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/routes.dart';
import '../../core/theme/app_colors.dart';
import 'data/home_repository.dart';
import 'model/home_summary.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/routes.dart';
import '../../core/theme/app_colors.dart';
import 'data/home_repository.dart';
import 'model/home_summary.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _repo = HomeRepository();
  late Future<HomeSummary> _future;

  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    _future = _repo.getHomeSummary();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _repo.getHomeSummary();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FutureBuilder<HomeSummary>(
          future: _future,
          initialData: HomeSummary.fallback(),
          builder: (context, snap) {
            final data = snap.data ?? HomeSummary.fallback();

            final percent = data.totalTasks == 0
                ? 0.0
                : (data.completedTasks / data.totalTasks).clamp(0.0, 1.0);

            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                children: [
                  if (snap.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: LinearProgressIndicator(),
                    ),

                  _Header(userName: data.userName),
                  const SizedBox(height: 16),

                  _ProgressCard(
                    completed: data.completedTasks,
                    total: data.totalTasks,
                    percent: percent,
                    badge: data.progressText,
                  ),

                  const SizedBox(height: 18),
                  const Text(
                    "Quick Actions",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.file_upload_outlined,
                          label: "Upload",
                          onTap: () => context.push(AppRoutes.upload),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.quiz_outlined,
                          label: "Quiz Me",
                          onTap: () {
                            // context.push('/quiz');
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.add_task_outlined,
                          label: "Add Goal",
                          onTap: () => context.push(AppRoutes.addGoal),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Text(
                        "Next Task",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          // context.push('/schedule');
                        },
                        child: const Text("View Schedule"),
                      ),
                    ],
                  ),

                  _NextTaskCard(
                    tag: data.nextTask.subjectTag,
                    title: data.nextTask.title,
                    time: data.nextTask.timeLabel,
                    description: data.nextTask.description,
                    onStart: () {
                      // POST /api/tasks/{id}/start
                    },
                  ),

                  const SizedBox(height: 16),
                  _AiTipCard(message: data.aiTip.message),

                  if (snap.hasError) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.25),
                        ),
                      ),
                      child: const Text(
                        "Could not load latest home data. Showing default data.",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _navIndex,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        onTap: (i) {
          setState(() {
            _navIndex = i;
          });

          if (i == 0) context.go(AppRoutes.home);
          if (i == 1) context.go(AppRoutes.library);
          if (i == 2) {
            // context.go('/schedule');
          }
          if (i == 3) {
            // context.go('/settings');
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            label: "Library",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            label: "Schedule",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: "Settings",
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 2),
            color: AppColors.surface,
          ),
          child: const Icon(Icons.person, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome back,",
              style: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.9),
              ),
            ),
            Text(
              userName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.completed,
    required this.total,
    required this.percent,
    required this.badge,
  });

  final int completed;
  final int total;
  final double percent;
  final String badge;

  @override
  Widget build(BuildContext context) {
    final remaining = (total - completed) < 0 ? 0 : (total - completed);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            height: 74,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: percent,
                  strokeWidth: 7,
                  backgroundColor: AppColors.outline,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                ),
                Text(
                  "$completed/$total",
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      "Today's Progress",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  total == 0
                      ? "No study tasks yet. Add a goal or upload notes to get started."
                      : "You're on track! Just $remaining more tasks to hit your daily goal.",
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: List.generate(5, (i) {
                    final active = i < (percent * 5).round();
                    return Container(
                      width: 22,
                      height: 6,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: active ? AppColors.primary : AppColors.outline,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outline),
        ),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _NextTaskCard extends StatelessWidget {
  const _NextTaskCard({
    required this.tag,
    required this.title,
    required this.time,
    required this.description,
    required this.onStart,
  });

  final String tag;
  final String title;
  final String time;
  final String description;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final hasTask = title.trim().toLowerCase() != 'no upcoming task';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          Container(
            height: 170,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              color: const Color(0xFF2F5C55),
            ),
            child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (time.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              time,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        description,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: hasTask ? onStart : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(hasTask ? "Start Now" : "No Task"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiTipCard extends StatelessWidget {
  const _AiTipCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.75),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.lightbulb_outline, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "AI Study Tip",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
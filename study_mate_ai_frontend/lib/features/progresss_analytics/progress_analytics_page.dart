import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../core/theme/app_colors.dart';
import '../../core/config/routes.dart';
import '../../services/token_storage.dart';
import '../../services/api_config.dart';

class ProgressAnalyticsPage extends StatefulWidget {
  const ProgressAnalyticsPage({super.key});

  @override
  State<ProgressAnalyticsPage> createState() => _ProgressAnalyticsPageState();
}

class _ProgressAnalyticsPageState extends State<ProgressAnalyticsPage> {
  int _selectedPeriod = 0;
  final List<String> _periods = ['This Week', 'This Month', 'This Semester'];
  int _navIndex = 2;

  // Data from backend
  int _streakDays = 0;
  double _studyHours = 0;
  double _overallMastery = 0;
  double _avgQuizScore = 0;
  double _quizScoreChange = 0;
  int _totalTasks = 0;
  int _completedTasks = 0;
  List<double> _weeklyScores = [0, 0, 0, 0, 0, 0, 0];
  List<_SubjectProgress> _subjects = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final token = await TokenStorage.getToken();
      final baseUrl = ApiConfig.baseUrl;

      // Call the real analytics endpoint
      final res = await http
          .get(
            Uri.parse('$baseUrl/api/progress/analytics'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        setState(() {
          _streakDays = data['streakDays'] ?? 0;
          _studyHours = (data['studyHours'] as num?)?.toDouble() ?? 0;
          _overallMastery = (data['overallMastery'] as num?)?.toDouble() ?? 0;
          _totalTasks = data['totalTasks'] ?? 0;
          _completedTasks = data['completedTasks'] ?? 0;
          _avgQuizScore = (data['avgQuizScore'] as num?)?.toDouble() ?? 0;
          _quizScoreChange = (data['quizScoreChange'] as num?)?.toDouble() ?? 0;

          // Weekly scores
          if (data['weeklyScores'] is List) {
            _weeklyScores = (data['weeklyScores'] as List)
                .map((e) => (e as num).toDouble())
                .toList();
            while (_weeklyScores.length < 7) {
              _weeklyScores.add(0);
            }
          }

          // Subjects
          if (data['subjects'] is List) {
            _subjects = (data['subjects'] as List).map((s) {
              return _SubjectProgress(
                name: s['name'] ?? 'General',
                progress: (s['progress'] as num?)?.toDouble() ?? 0,
                level: s['level'] ?? 'Beginner',
                totalTasks: s['totalTasks'] ?? 0,
                completedTasks: s['completedTasks'] ?? 0,
              );
            }).toList();
          }
        });
      } else {
        // Fallback to showing zeros
        print('Analytics API returned: ${res.statusCode}');
      }
    } catch (e) {
      print('Analytics load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onNavTap(int i) {
    setState(() => _navIndex = i);
    switch (i) {
      case 0:
        context.go(AppRoutes.home);
        break;
      case 1:
        context.go(AppRoutes.library);
        break;
      case 2:
        // Already on analytics
        break;
      case 3:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 90),
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Progress & Analytics',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.refresh_outlined),
                          onPressed: _loadData,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Period selector
                    _PeriodSelector(
                      periods: _periods,
                      selected: _selectedPeriod,
                      onChanged: (i) => setState(() => _selectedPeriod = i),
                    ),
                    const SizedBox(height: 16),

                    // Streak & Study Hours
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.local_fire_department,
                            iconColor: Colors.orange,
                            label: 'Streak',
                            value: '$_streakDays Days',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.schedule,
                            iconColor: AppColors.primary,
                            label: 'Study Hours',
                            value: '${_studyHours.toStringAsFixed(1)}h',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Task completion
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.task_alt,
                            iconColor: AppColors.success,
                            label: 'Tasks Done',
                            value: '$_completedTasks/$_totalTasks',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.trending_up,
                            iconColor: AppColors.tealAccent,
                            label: 'Mastery',
                            value: '${_overallMastery.round()}%',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Topic Mastery
                    const Text(
                      'Topic Mastery',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _TopicMasteryCard(
                      subjects: _subjects,
                      overall: _overallMastery,
                    ),
                    const SizedBox(height: 20),

                    // Quiz Performance
                    const Text(
                      'Quiz Performance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _QuizPerformanceCard(
                      avgScore: _avgQuizScore,
                      change: _quizScoreChange,
                      weeklyScores: _weeklyScores,
                    ),
                    const SizedBox(height: 20),

                    // Subject progress list
                    if (_subjects.isNotEmpty) ...[
                      const Text(
                        'Subject Breakdown',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._subjects.map((s) => _SubjectProgressCard(subject: s)),
                    ],

                    if (_subjects.isEmpty && _totalTasks == 0) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.outline),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.bar_chart_outlined,
                              size: 48,
                              color: AppColors.textSecondary.withOpacity(0.4),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No data yet',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Upload notes, generate a study plan, and take quizzes to see your progress here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _navIndex,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        onTap: _onNavTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'Library',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// ═══════════════════ Sub-widgets ═══════════════════

class _PeriodSelector extends StatelessWidget {
  final List<String> periods;
  final int selected;
  final ValueChanged<int> onChanged;

  const _PeriodSelector({
    required this.periods,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: periods.asMap().entries.map((e) {
          final isActive = e.key == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    e.value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isActive ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label, value;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _TopicMasteryCard extends StatelessWidget {
  final List<_SubjectProgress> subjects;
  final double overall;

  const _TopicMasteryCard({required this.subjects, required this.overall});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: subjects.isEmpty
                ? Center(
                    child: Text(
                      'Generate a study plan to see mastery',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  )
                : CustomPaint(
                    size: const Size(180, 180),
                    painter: _RadarPainter(
                      subjects: subjects,
                      primaryColor: AppColors.primary,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Text(
            '${overall.round()}% Overall',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            subjects.isNotEmpty
                ? '${subjects.where((s) => s.progress >= 0.8).length} of ${subjects.length} subjects mastered'
                : 'Upload materials to track mastery',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<_SubjectProgress> subjects;
  final Color primaryColor;

  _RadarPainter({required this.subjects, required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 20;
    final n = max(subjects.length, 3);

    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int ring = 1; ring <= 3; ring++) {
      final r = radius * ring / 3;
      final path = Path();
      for (int i = 0; i <= n; i++) {
        final angle = -pi / 2 + 2 * pi * i / n;
        final x = center.dx + r * cos(angle);
        final y = center.dy + r * sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, gridPaint);
    }

    for (int i = 0; i < n; i++) {
      final angle = -pi / 2 + 2 * pi * i / n;
      canvas.drawLine(
        center,
        Offset(
          center.dx + radius * cos(angle),
          center.dy + radius * sin(angle),
        ),
        gridPaint,
      );
    }

    if (subjects.isNotEmpty) {
      final dataPaint = Paint()
        ..color = primaryColor.withOpacity(0.3)
        ..style = PaintingStyle.fill;

      final borderPaint = Paint()
        ..color = primaryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      final dataPath = Path();
      for (int i = 0; i <= n; i++) {
        final idx = i % subjects.length;
        final val = subjects[idx].progress;
        final angle = -pi / 2 + 2 * pi * i / n;
        final r = radius * val;
        final x = center.dx + r * cos(angle);
        final y = center.dy + r * sin(angle);
        if (i == 0) {
          dataPath.moveTo(x, y);
        } else {
          dataPath.lineTo(x, y);
        }
      }
      canvas.drawPath(dataPath, dataPaint);
      canvas.drawPath(dataPath, borderPaint);

      final dotPaint = Paint()
        ..color = primaryColor
        ..style = PaintingStyle.fill;

      for (int i = 0; i < n; i++) {
        final idx = i % subjects.length;
        final val = subjects[idx].progress;
        final angle = -pi / 2 + 2 * pi * i / n;
        final r = radius * val;
        canvas.drawCircle(
          Offset(center.dx + r * cos(angle), center.dy + r * sin(angle)),
          4,
          dotPaint,
        );
      }

      final textPainter = TextPainter(textDirection: TextDirection.ltr);
      for (int i = 0; i < min(subjects.length, n); i++) {
        final angle = -pi / 2 + 2 * pi * i / n;
        final labelR = radius + 16;
        final x = center.dx + labelR * cos(angle);
        final y = center.dy + labelR * sin(angle);

        textPainter.text = TextSpan(
          text: subjects[i].name.length > 10
              ? subjects[i].name.substring(0, 10).toUpperCase()
              : subjects[i].name.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Colors.grey[600],
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, y - textPainter.height / 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _QuizPerformanceCard extends StatelessWidget {
  final double avgScore, change;
  final List<double> weeklyScores;

  const _QuizPerformanceCard({
    required this.avgScore,
    required this.change,
    required this.weeklyScores,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = avgScore > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'AVG. SCORE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              if (hasData && change != 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      change >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 14,
                      color: change >= 0 ? AppColors.success : AppColors.error,
                    ),
                    Text(
                      '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)} pts',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: change >= 0
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            hasData ? avgScore.toStringAsFixed(1) : '—',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
          ),
          if (!hasData) ...[
            const SizedBox(height: 8),
            Text(
              'Take a quiz to see your scores here',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
          if (hasData) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 80,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                    .asMap()
                    .entries
                    .map((e) {
                      final i = e.key;
                      final label = e.value;
                      final val = i < weeklyScores.length ? weeklyScores[i] : 0;
                      final maxVal = weeklyScores.reduce(max);
                      final h = maxVal > 0 ? (val / maxVal * 60) : 0.0;

                      return Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: h,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(
                                  val > 70 ? 1 : 0.4,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    })
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubjectProgressCard extends StatelessWidget {
  final _SubjectProgress subject;

  const _SubjectProgressCard({required this.subject});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.menu_book,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${(subject.progress * 100).round()}% • ${subject.level} • ${subject.completedTasks}/${subject.totalTasks} tasks',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: subject.progress,
                backgroundColor: AppColors.outline,
                valueColor: AlwaysStoppedAnimation(
                  subject.progress >= 0.8
                      ? AppColors.success
                      : subject.progress >= 0.4
                      ? AppColors.primary
                      : AppColors.warning,
                ),
                minHeight: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectProgress {
  final String name;
  final double progress;
  final String level;
  final int totalTasks;
  final int completedTasks;

  _SubjectProgress({
    required this.name,
    required this.progress,
    required this.level,
    this.totalTasks = 0,
    this.completedTasks = 0,
  });
}

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/theme/app_colors.dart';
import '../../services/token_storage.dart';
import '../../services/api_config.dart';

class ProgressAnalyticsPage extends StatefulWidget {
  const ProgressAnalyticsPage({super.key});

  @override
  State<ProgressAnalyticsPage> createState() => _ProgressAnalyticsPageState();
}

class _ProgressAnalyticsPageState extends State<ProgressAnalyticsPage> {
  int _selectedPeriod = 0; // 0=This Week, 1=This Month, 2=This Semester
  final List<String> _periods = ['This Week', 'This Month', 'This Semester'];

  // Data from backend
  int _streakDays = 0;
  double _studyHours = 0;
  double _overallMastery = 0;
  double _avgQuizScore = 0;
  double _quizScoreChange = 0;
  List<double> _weeklyScores = [0, 0, 0, 0, 0, 0, 0];
  List<_SubjectProgress> _subjects = [];
  String _peakTime = '7 PM';
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

      // Load home summary for basic stats
      final homeRes = await http
          .get(
            Uri.parse('$baseUrl/api/home/summary'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (homeRes.statusCode == 200) {
        final data = jsonDecode(homeRes.body);
        final completed = data['completedTasks'] ?? 0;
        final total = data['totalTasks'] ?? 0;

        setState(() {
          _streakDays = max(1, completed);
          _studyHours = (completed * 1.5).toDouble();
          _overallMastery = total > 0 ? (completed / total * 100) : 0;
        });
      }

      // Load materials to calculate subject progress
      final matRes = await http
          .get(
            Uri.parse('$baseUrl/api/materials'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (matRes.statusCode == 200) {
        final materials = jsonDecode(matRes.body) as List;
        Map<String, int> subjectCounts = {};
        Map<String, int> readyCounts = {};

        for (var m in materials) {
          final subject = (m['subjectName'] ?? 'General').toString();
          subjectCounts[subject] = (subjectCounts[subject] ?? 0) + 1;
          final status = (m['processingStatus'] ?? '').toString().toUpperCase();
          if (status.contains('READY') ||
              status.contains('QUIZ') ||
              status.contains('PLAN')) {
            readyCounts[subject] = (readyCounts[subject] ?? 0) + 1;
          }
        }

        final subjects = <_SubjectProgress>[];
        for (var entry in subjectCounts.entries) {
          final ready = readyCounts[entry.key] ?? 0;
          final total = entry.value;
          subjects.add(
            _SubjectProgress(
              name: entry.key,
              progress: total > 0 ? (ready / total) : 0,
              level: ready >= 3
                  ? 'Advanced'
                  : ready >= 1
                  ? 'Proficient'
                  : 'Beginner',
            ),
          );
        }

        setState(() {
          _subjects = subjects;
          _avgQuizScore = 75 + Random().nextDouble() * 20; // simulated
          _quizScoreChange = Random().nextDouble() * 15;
          _weeklyScores = List.generate(
            7,
            (_) => 50 + Random().nextDouble() * 50,
          );
        });
      }
    } catch (e) {
      // Use fallback data
      setState(() {
        _streakDays = 12;
        _studyHours = 48.5;
        _overallMastery = 82;
        _avgQuizScore = 94.2;
        _quizScoreChange = 12.4;
        _weeklyScores = [65, 70, 85, 60, 90, 78, 88];
        _subjects = [
          _SubjectProgress(
            name: 'Calculus III',
            progress: 0.95,
            level: 'Proficient',
          ),
          _SubjectProgress(
            name: 'Molecular Bio',
            progress: 0.44,
            level: 'Proficient',
          ),
          _SubjectProgress(name: 'History', progress: 0.72, level: 'Advanced'),
        ];
      });
    } finally {
      if (mounted) setState(() => _loading = false);
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
                          icon: const Icon(Icons.calendar_month_outlined),
                          onPressed: () {},
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
                            change: '+2%',
                            positive: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.schedule,
                            iconColor: AppColors.primary,
                            label: 'Study Hours',
                            value: '${_studyHours.toStringAsFixed(1)}h',
                            change: '-5%',
                            positive: false,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Topic Mastery - Radar-like visualization
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

                    // Peak Productivity
                    _InsightCard(
                      icon: Icons.bolt,
                      iconColor: Colors.amber,
                      title: 'Peak Productivity',
                      subtitle:
                          "You're most productive at $_peakTime. Focus on your hardest tasks then!",
                    ),
                    const SizedBox(height: 12),

                    // Subject progress list
                    if (_subjects.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ..._subjects.map((s) => _SubjectProgressCard(subject: s)),
                    ],
                  ],
                ),
              ),
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
  final String label, value, change;
  final bool positive;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.change,
    required this.positive,
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
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                positive ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
                color: positive ? AppColors.success : AppColors.error,
              ),
              Text(
                change,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: positive ? AppColors.success : AppColors.error,
                ),
              ),
            ],
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
          // Simple radar-like visualization using CustomPaint
          SizedBox(
            height: 180,
            child: CustomPaint(
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
                ? 'Excellent progress in ${subjects.first.name}'
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

    // Draw grid
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

    // Draw axes
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

    // Draw data polygon
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

      // Draw dots
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

      // Draw labels
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_upward, size: 14, color: AppColors.success),
                  Text(
                    '+${change.toStringAsFixed(1)} pts',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            avgScore.toStringAsFixed(1),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),

          // Bar chart
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].asMap().entries.map(
                (e) {
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
                },
              ).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;

  const _InsightCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
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
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
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
                  '${(subject.progress * 100).round()}% ${subject.level}',
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
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
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

  _SubjectProgress({
    required this.name,
    required this.progress,
    required this.level,
  });
}

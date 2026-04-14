import 'dart:math';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../shared/ai_widgets.dart';
import 'study_plan_repository.dart';

class StudyPlanPage extends StatefulWidget {
  final int materialId;
  const StudyPlanPage({super.key, required this.materialId});

  @override
  State<StudyPlanPage> createState() => _StudyPlanPageState();
}

class _StudyPlanPageState extends State<StudyPlanPage> {
  final _repo = StudyPlanRepository();

  bool _loading = true;
  bool _rescheduling = false;
  StudyPlanData? _plan;
  String? _error;
  int _selectedDayIdx = 0;

  // Time slots for the visual schedule
  final _timeSlots = [
    '09:00',
    '10:00',
    '11:00',
    '12:00',
    '14:00',
    '15:00',
    '16:00',
    '17:00',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      StudyPlanData data;
      try {
        data = await _repo.getPlan(widget.materialId);
        if (!data.hasPlan || data.days.isEmpty) {
          data = await _repo.generatePlan(widget.materialId);
        }
      } catch (_) {
        data = await _repo.generatePlan(widget.materialId);
      }
      if (!mounted) return;
      setState(() {
        _plan = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _reschedule() async {
    setState(() => _rescheduling = true);
    try {
      final data = await _repo.reschedule(widget.materialId);
      if (!mounted) return;
      setState(() {
        _plan = data;
        _rescheduling = false;
        _selectedDayIdx = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plan rescheduled! Missed tasks moved forward.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _rescheduling = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _toggleTask(PlanTask task) async {
    final prev = task.completed;
    setState(() => task.completed = !prev);
    try {
      await _repo.toggleTask(task.id, !prev);
    } catch (_) {
      if (mounted) setState(() => task.completed = prev);
    }
  }

  // Map tasks to time slots
  List<_SlotEntry> _buildTimeSlots(PlanDay day) {
    final entries = <_SlotEntry>[];
    for (int i = 0; i < day.tasks.length; i++) {
      final slot = i < _timeSlots.length
          ? _timeSlots[i]
          : '${17 + (i - _timeSlots.length + 1)}:00';
      entries.add(_SlotEntry(time: slot, task: day.tasks[i]));
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        body: const Center(
          child: AiProcessingIndicator(
            message: 'Optimizing your schedule',
            subMessage:
                'Running genetic algorithm to build\nyour personalized study plan',
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        body: AiEmptyState(
          icon: Icons.error_outline,
          title: 'Failed to load plan',
          subtitle: _error!.length > 80
              ? '${_error!.substring(0, 80)}...'
              : _error!,
          buttonLabel: 'Retry',
          onButton: _load,
        ),
      );
    }

    if (_plan == null || !_plan!.hasPlan) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        body: AiEmptyState(
          icon: Icons.calendar_today_outlined,
          title: 'No study plan yet',
          subtitle:
              'Generate an overview and take a quiz\nso AI can build your schedule.',
          buttonLabel: 'Go Back',
          onButton: () => Navigator.pop(context),
        ),
      );
    }

    return _buildPlannerView();
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      centerTitle: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          const Text(
            'Study Planner',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
        ],
      ),
      actions: [
        if (_plan != null)
          IconButton(
            onPressed: _rescheduling ? null : _reschedule,
            tooltip: 'Reschedule missed tasks',
            icon: _rescheduling
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
      ],
    );
  }

  // ════════════════════════════════════════
  // Main planner view
  // ════════════════════════════════════════

  Widget _buildPlannerView() {
    final plan = _plan!;
    final selectedDay = _selectedDayIdx < plan.days.length
        ? plan.days[_selectedDayIdx]
        : null;
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // ── Week date strip ──
          _WeekStrip(
            days: plan.days,
            selectedIndex: _selectedDayIdx,
            startDate: now,
            onSelect: (i) => setState(() => _selectedDayIdx = i),
          ),

          // ── Today's Focus header ──
          if (selectedDay != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(
                    selectedDay.label,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${selectedDay.tasks.length - selectedDay.completedCount} tasks left',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Time-slotted tasks ──
          if (selectedDay != null)
            Expanded(
              child: selectedDay.tasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_available,
                            size: 48,
                            color: AppColors.textSecondary.withOpacity(0.3),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Rest day',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      children: _buildTimeSlots(selectedDay).map((entry) {
                        return _TimeSlotCard(
                          time: entry.time,
                          task: entry.task,
                          onToggle: () => _toggleTask(entry.task),
                          onAccept: entry.task.isRescheduled
                              ? () => _toggleTask(entry.task)
                              : null,
                          onDismiss: entry.task.isRescheduled
                              ? () => _reschedule()
                              : null,
                        );
                      }).toList(),
                    ),
            ),
        ],
      ),
    );
  }
}

class _SlotEntry {
  final String time;
  final PlanTask task;
  _SlotEntry({required this.time, required this.task});
}

// ════════════════════════════════════════════
// Week strip (matches the reference design)
// ════════════════════════════════════════════

class _WeekStrip extends StatelessWidget {
  final List<PlanDay> days;
  final int selectedIndex;
  final DateTime startDate;
  final ValueChanged<int> onSelect;

  const _WeekStrip({
    required this.days,
    required this.selectedIndex,
    required this.startDate,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final dayNames = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.outline)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(min(days.length, 7), (i) {
          final date = startDate.add(Duration(days: i));
          final dayName = dayNames[date.weekday % 7];
          final dayNum = date.day;
          final isSelected = i == selectedIndex;
          final day = days[i];
          final isDone = day.allCompleted && day.tasks.isNotEmpty;
          final hasTasks = day.tasks.isNotEmpty;

          return GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dayName,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white70
                          : AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$dayNum',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Dot indicator
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: !hasTasks
                          ? Colors.transparent
                          : isDone
                          ? (isSelected ? Colors.white : AppColors.success)
                          : (isSelected
                                ? Colors.white60
                                : AppColors.primary.withOpacity(0.4)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ════════════════════════════════════════════
// Time-slot task card
// ════════════════════════════════════════════

class _TimeSlotCard extends StatelessWidget {
  final String time;
  final PlanTask task;
  final VoidCallback onToggle;
  final VoidCallback? onAccept;
  final VoidCallback? onDismiss;

  const _TimeSlotCard({
    required this.time,
    required this.task,
    required this.onToggle,
    this.onAccept,
    this.onDismiss,
  });

  Color _typeColor() {
    if (task.isRescheduled) return AppColors.warning;
    return switch (task.taskType) {
      'READ' => AppColors.primary,
      'REVIEW' => const Color(0xFF4FA7A1),
      'QUIZ' => const Color(0xFFE5484D),
      'DEEP_REVIEW' => const Color(0xFFF5A524),
      _ => AppColors.primary,
    };
  }

  IconData _typeIcon() {
    if (task.isRescheduled) return Icons.schedule_rounded;
    return switch (task.taskType) {
      'READ' => Icons.menu_book_rounded,
      'REVIEW' => Icons.style_rounded,
      'QUIZ' => Icons.quiz_rounded,
      'DEEP_REVIEW' => Icons.psychology_rounded,
      _ => Icons.task_rounded,
    };
  }

  String _typeLabel() {
    if (task.isRescheduled) return 'AI RECOMMENDATION';
    return switch (task.taskType) {
      'READ' => 'STUDY',
      'REVIEW' => 'REVIEW',
      'QUIZ' => 'PRACTICE',
      'DEEP_REVIEW' => 'FOCUS SESSION',
      _ => 'STUDY',
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _typeColor();
    final isDone = task.completed;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time label
            SizedBox(
              width: 48,
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  time,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary.withOpacity(0.6),
                  ),
                ),
              ),
            ),

            // Vertical line + dot
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  const SizedBox(height: 18),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone ? AppColors.success : color,
                      border: Border.all(
                        color: isDone ? AppColors.success : color,
                        width: 2,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.outline.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Card
            Expanded(
              child: task.isRescheduled
                  ? _buildRescheduledCard(color)
                  : _buildNormalCard(color, isDone),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNormalCard(Color color, bool isDone) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDone
              ? AppColors.surface.withOpacity(0.7)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDone
                ? AppColors.success.withOpacity(0.3)
                : AppColors.outline,
          ),
          boxShadow: isDone
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Left color bar
            Container(
              width: 4,
              height: 44,
              decoration: BoxDecoration(
                color: isDone ? AppColors.success : color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),

            // Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (isDone ? AppColors.success : color).withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _typeIcon(),
                size: 18,
                color: isDone ? AppColors.success : color,
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _typeLabel(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isDone ? AppColors.textSecondary : color,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDone
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (task.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      task.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary.withOpacity(0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Duration + checkbox
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${task.estimatedMinutes}m',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDone
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isDone ? AppColors.success : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDone ? AppColors.success : AppColors.outline,
                      width: 2,
                    ),
                  ),
                  child: isDone
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRescheduledCard(Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.warning.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.warning.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI recommendation badge
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 14, color: AppColors.warning),
              const SizedBox(width: 6),
              Text(
                'AI RECOMMENDATION',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.warning,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            task.title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Rescheduled — ${task.description.isNotEmpty ? task.description : "Moved from a missed session"}',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 12),

          // Accept / Dismiss buttons
          Row(
            children: [
              _SmallButton(
                label: 'Accept',
                filled: true,
                onTap: onAccept ?? () {},
              ),
              const SizedBox(width: 10),
              _SmallButton(
                label: 'Dismiss',
                filled: false,
                onTap: onDismiss ?? () {},
              ),
              const Spacer(),
              Text(
                '${task.estimatedMinutes}m',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _SmallButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: filled ? AppColors.primary : AppColors.outline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: filled ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

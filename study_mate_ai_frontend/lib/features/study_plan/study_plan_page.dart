import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/routes.dart';
import '../../core/theme/app_colors.dart';
import '../shared/app_bottom_nav.dart';
import '../shared/ai_widgets.dart';
import '../quiz/quiz_page.dart';
import '../study_plan/flashcard_study_page.dart';
import 'study_plan_repository.dart';

class StudyPlanPage extends StatefulWidget {
  final int materialId;
  const StudyPlanPage({super.key, required this.materialId});
  @override
  State<StudyPlanPage> createState() => _StudyPlanPageState();
}

class _StudyPlanPageState extends State<StudyPlanPage> {
  final _repo = StudyPlanRepository();
  bool _loading = true, _rescheduling = false;
  StudyPlanData? _plan;
  String? _error;
  int _sel = 0;

  final _slots = ['09:00','10:00','11:00','12:00','14:00',
                  '15:00','16:00','17:00','18:00','19:00'];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      StudyPlanData d;
      try {
        d = await _repo.getPlan(widget.materialId);
        if (!d.hasPlan || d.days.isEmpty)
          d = await _repo.generatePlan(widget.materialId);
      } catch (_) { d = await _repo.generatePlan(widget.materialId); }
      if (!mounted) return;
      setState(() { _plan = d; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _reschedule() async {
    setState(() => _rescheduling = true);
    try {
      final d = await _repo.reschedule(widget.materialId);
      if (!mounted) return;
      setState(() { _plan = d; _rescheduling = false; _sel = 0; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan rescheduled!'),
            behavior: SnackBarBehavior.floating));
    } catch (_) {
      if (!mounted) return;
      setState(() => _rescheduling = false);
    }
  }

  Future<void> _toggle(PlanTask task) async {
    final prev = task.completed;
    setState(() => task.completed = !prev);
    try { await _repo.toggleTask(task.id, !prev); }
    catch (_) { if (mounted) setState(() => task.completed = prev); }
  }

  String _topic(String title) {
    final i = title.indexOf(':');
    return i > 0 ? title.substring(i + 1).trim() : title.trim();
  }

  void _handleTap(PlanTask task) {
    if (task.completed) return;
    final topic = _topic(task.title);
    if (task.taskType.toUpperCase() == 'QUIZ') {
      _openQuiz(task, topic);
    } else {
      _openFlashcards(task, topic);
    }
  }

  Future<void> _openFlashcards(PlanTask task, String topic) async {
    final r = await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => FlashcardStudyPage(
        materialId: widget.materialId, topic: topic,
        schedulerTaskId: task.id)));
    if (r == true && mounted) setState(() => task.completed = true);
  }

  Future<void> _openQuiz(PlanTask task, String topic) async {
    final r = await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => QuizPage(
        materialId: widget.materialId, topicLabel: topic,
        schedulerTaskId: task.id)));
    if (r == true && mounted) setState(() => task.completed = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
          SizedBox(width: 6),
          Text('Study Planner',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        ]),
        actions: [
          if (!_loading && _plan != null)
            IconButton(
              onPressed: _rescheduling ? null : _reschedule,
              icon: _rescheduling
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _body(),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: AiProcessingIndicator(
      message: 'Building your schedule',
      subMessage: 'Optimizing with AI'));
    if (_error != null) return AiEmptyState(
      icon: Icons.error_outline, title: 'Failed to load plan',
      subtitle: _error!.length > 100
          ? '${_error!.substring(0, 100)}...' : _error!,
      buttonLabel: 'Retry', onButton: _load);
    if (_plan == null || !_plan!.hasPlan) return AiEmptyState(
      icon: Icons.calendar_today_outlined, title: 'No study plan yet',
      subtitle: 'Open a note and generate an overview first.',
      buttonLabel: 'Go to Library',
      onButton: () => context.go(AppRoutes.library));

    final plan = _plan!;
    final day = _sel < plan.days.length ? plan.days[_sel] : null;
    final now = DateTime.now();

    return Column(children: [
      _WeekStrip(days: plan.days, selected: _sel,
        start: now, onSelect: (i) => setState(() => _sel = i)),
      if (day != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
          child: Row(children: [
            Text(day.label, style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(9)),
              child: Text(
                '${day.tasks.length - day.completedCount} left',
                style: const TextStyle(color: AppColors.primary,
                    fontWeight: FontWeight.w700, fontSize: 12))),
          ])),
      if (day != null)
        Expanded(
          child: day.tasks.isEmpty
            ? const Center(child: Text('Rest day 🎉',
                style: TextStyle(color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
                itemCount: day.tasks.length,
                itemBuilder: (_, i) {
                  final task = day.tasks[i];
                  final time = i < _slots.length
                      ? _slots[i] : '${18 + i - _slots.length}:00';
                  return _TaskCard(
                    time: time, task: task,
                    onTap: () => _handleTap(task),
                    onToggle: () => _toggle(task));
                })),
    ]);
  }
}

// ── Week Strip ───────────────────────────────────────────────────────

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.days, required this.selected,
    required this.start, required this.onSelect});
  final List<PlanDay> days; final int selected;
  final DateTime start; final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    const names = ['SUN','MON','TUE','WED','THU','FRI','SAT'];
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(
            color: Theme.of(context).dividerColor))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(min(days.length, 7), (i) {
          final date = start.add(Duration(days: i));
          final isSel = i == selected;
          final d = days[i];
          final hasTasks = d.tasks.isNotEmpty;
          final allDone = d.allCompleted && hasTasks;
          final dotColor = !hasTasks ? Colors.transparent
              : allDone
                ? (isSel ? Colors.white : AppColors.success)
                : (isSel
                  ? Colors.white60
                  : AppColors.primary.withOpacity(0.5));

          return GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44, padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSel ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(14)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(names[date.weekday % 7], style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: isSel ? Colors.white70
                      : cs.onSurface.withOpacity(0.5))),
                const SizedBox(height: 5),
                Text('${date.day}', style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800,
                  color: isSel ? Colors.white : cs.onSurface)),
                const SizedBox(height: 4),
                Container(width: 6, height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, color: dotColor)),
              ])));
        })));
  }
}

// ── Task Card ────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.time, required this.task,
    required this.onTap, required this.onToggle});
  final String time; final PlanTask task;
  final VoidCallback onTap, onToggle;

  Color get _color => switch (task.taskType.toUpperCase()) {
    'QUIZ' => const Color(0xFFE5484D),
    'REVIEW' => const Color(0xFF4FA7A1),
    'DEEP_REVIEW' => const Color(0xFFF5A524),
    _ => AppColors.primary };
  IconData get _icon => switch (task.taskType.toUpperCase()) {
    'QUIZ' => Icons.quiz_rounded,
    'REVIEW' => Icons.style_rounded,
    'DEEP_REVIEW' => Icons.psychology_rounded,
    _ => Icons.menu_book_rounded };
  String get _label => switch (task.taskType.toUpperCase()) {
    'QUIZ' => 'QUIZ', 'REVIEW' => 'REVIEW',
    'DEEP_REVIEW' => 'FOCUS', _ => 'STUDY' };
  String get _hint => task.taskType.toUpperCase() == 'QUIZ'
    ? 'Tap to start quiz' : 'Tap to study flashcards';

  @override
  Widget build(BuildContext context) {
    final c = _color; final done = task.completed;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: IntrinsicHeight(child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 48, child: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(time, style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: cs.onSurface.withOpacity(0.4))))),
          SizedBox(width: 24, child: Column(children: [
            const SizedBox(height: 18),
            Container(width: 10, height: 10, decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? AppColors.success : c)),
            Expanded(child: Container(width: 2,
              color: Theme.of(context).dividerColor.withOpacity(0.5))),
          ])),
          const SizedBox(width: 8),
          Expanded(child: GestureDetector(
            onTap: done ? null : onTap,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: done
                      ? AppColors.success.withOpacity(0.25)
                      : c.withOpacity(0.3),
                  width: done ? 1 : 1.5)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(width: 4, height: 38,
                      decoration: BoxDecoration(
                        color: done ? AppColors.success : c,
                        borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 10),
                    Container(width: 33, height: 33,
                      decoration: BoxDecoration(
                        color: (done ? AppColors.success : c)
                            .withOpacity(0.10),
                        borderRadius: BorderRadius.circular(9)),
                      child: Icon(_icon, size: 16,
                          color: done ? AppColors.success : c)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_label, style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w800,
                          color: done
                              ? cs.onSurface.withOpacity(0.4) : c,
                          letterSpacing: 0.6)),
                        const SizedBox(height: 2),
                        Text(task.title, style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: done
                              ? cs.onSurface.withOpacity(0.4)
                              : cs.onSurface,
                          decoration: done
                              ? TextDecoration.lineThrough : null),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      ])),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${task.estimatedMinutes}m',
                          style: TextStyle(fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: done
                                ? cs.onSurface.withOpacity(0.4)
                                : cs.onSurface)),
                        const SizedBox(height: 4),
                        if (done)
                          Container(width: 22, height: 22,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(6)),
                            child: const Icon(Icons.check,
                                color: Colors.white, size: 14))
                        else
                          GestureDetector(onTap: onToggle,
                            child: Container(width: 22, height: 22,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: cs.onSurface.withOpacity(0.3),
                                  width: 2),
                                borderRadius:
                                    BorderRadius.circular(6)))),
                      ]),
                  ]),
                  if (!done) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: c.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_arrow_rounded,
                              color: c, size: 15),
                          const SizedBox(width: 4),
                          Text(_hint, style: TextStyle(color: c,
                            fontWeight: FontWeight.w700, fontSize: 11)),
                        ])),
                  ],
                ]))));
        ])));
  }
}
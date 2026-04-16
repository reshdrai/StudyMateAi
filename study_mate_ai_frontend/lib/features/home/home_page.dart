import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/routes.dart';
import '../../core/theme/app_colors.dart';
import '../shared/app_bottom_nav.dart';
import 'data/home_repository.dart';
import '../study_plan/study_plan_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _repo = HomeRepository();
  late Future<HomeSummary> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<HomeSummary> _load() async {
    try { return await _repo.getHomeSummary(); }
    catch (_) { return HomeSummary.fallback; }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final card = Theme.of(context).cardColor;
    final div = Theme.of(context).dividerColor;

    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<HomeSummary>(
          future: _future,
          builder: (_, snap) {
            final d = snap.data ?? HomeSummary.fallback;
            return RefreshIndicator(
              onRefresh: () async {
                _future = _load();
                setState(() {});
                await _future;
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                children: [
                  if (snap.connectionState == ConnectionState.waiting)
                    LinearProgressIndicator(color: AppColors.primary,
                        backgroundColor: div),

                  // Header
                  Row(children: [
                    CircleAvatar(radius: 21,
                      backgroundColor: AppColors.primary.withOpacity(0.12),
                      child: Icon(Icons.person,
                          color: cs.onSurface.withOpacity(0.6))),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Welcome back,',
                        style: TextStyle(
                            color: cs.onSurface.withOpacity(0.55), fontSize: 13)),
                      Text(d.userName,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    ]),
                  ]),
                  const SizedBox(height: 16),

                  // Progress
                  _card(context, Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      SizedBox(width: 72, height: 72,
                        child: Stack(alignment: Alignment.center, children: [
                          CircularProgressIndicator(
                            value: d.progressRatio, strokeWidth: 7,
                            backgroundColor: div,
                            valueColor: const AlwaysStoppedAnimation(
                                AppColors.primary)),
                          Text('${d.completedTasks}/${d.totalTasks}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 13)),
                        ])),
                      const SizedBox(width: 14),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Expanded(child: Text("Today's Progress",
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w800))),
                            _pill(context, d.progressText, AppColors.primary),
                          ]),
                          const SizedBox(height: 7),
                          Text(
                            d.totalTasks == 0
                              ? 'Track a note from Library!'
                              : (d.totalTasks - d.completedTasks) == 0
                                ? 'All done today! 🎉'
                                : '${d.totalTasks - d.completedTasks} tasks remaining.',
                            style: TextStyle(
                                color: cs.onSurface.withOpacity(0.55),
                                fontSize: 12, height: 1.35)),
                          const SizedBox(height: 9),
                          Row(children: List.generate(5, (i) => Container(
                            width: 22, height: 6,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: i < (d.progressRatio * 5).round()
                                  ? AppColors.primary : div,
                              borderRadius: BorderRadius.circular(99))))),
                        ])),
                    ])),
                  )),
                  const SizedBox(height: 18),

                  // Quick Actions
                  const Text('Quick Actions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _actionCard(context,
                      Icons.file_upload_outlined, 'Upload',
                      () => context.push(AppRoutes.upload))),
                    const SizedBox(width: 12),
                    Expanded(child: _actionCard(context,
                      Icons.quiz_outlined, 'Quiz Me',
                      () => context.push(AppRoutes.library))),
                    const SizedBox(width: 12),
                    Expanded(child: _actionCard(context,
                      Icons.bar_chart_outlined, 'Analytics',
                      () => context.go(AppRoutes.analytics))),
                  ]),
                  const SizedBox(height: 20),

                  // Next Task
                  Row(children: [
                    const Text('Next Task',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    TextButton(onPressed: () => context.go(AppRoutes.library),
                      child: const Text('View Library')),
                  ]),
                  _NextTaskCard(task: d.nextTask,
                    onStart: d.nextTask?.materialId != null
                      ? () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => StudyPlanPage(
                                materialId: d.nextTask!.materialId!)))
                      : null),

                  // Upcoming
                  if (d.upcomingTasks.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('Upcoming Tasks',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    ...d.upcomingTasks.take(4).map((t) => _UpcomingTile(
                      task: t,
                      onTap: t.materialId != null
                        ? () => Navigator.push(context, MaterialPageRoute(
                              builder: (_) => StudyPlanPage(
                                  materialId: t.materialId!)))
                        : null)),
                  ],

                  const SizedBox(height: 16),
                  if (d.aiTip.isNotEmpty) _AiTip(message: d.aiTip),
                  const SizedBox(height: 20),

                  Row(children: [
                    const Text('Recent Notes',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    TextButton(onPressed: () => context.go(AppRoutes.library),
                      child: const Text('See All')),
                  ]),
                  _card(context, Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      Icon(Icons.note_add_outlined, size: 30,
                        color: cs.onSurface.withOpacity(0.3)),
                      const SizedBox(height: 8),
                      Text('Upload notes to see AI analysis here',
                        style: TextStyle(
                            color: cs.onSurface.withOpacity(0.5), fontSize: 13)),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: OutlinedButton(
                          onPressed: () => context.go(AppRoutes.library),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                          child: const Text('Browse'))),
                        const SizedBox(width: 12),
                        Expanded(child: ElevatedButton(
                          onPressed: () => context.push(AppRoutes.upload),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                          child: const Text('Upload'))),
                      ]),
                    ]),
                  )),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  Widget _card(BuildContext context, Widget child) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Theme.of(context).dividerColor)),
    child: child);

  Widget _actionCard(BuildContext context, IconData icon, String label,
      VoidCallback onTap) => InkWell(
    borderRadius: BorderRadius.circular(16), onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor)),
      child: Column(children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: AppColors.primary)),
        const SizedBox(height: 9),
        Text(label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
      ]),
    ));

  Widget _pill(BuildContext context, String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(999)),
    child: Text(text, style: TextStyle(
        color: color, fontWeight: FontWeight.w700, fontSize: 11)));
}

// ── Next Task ───────────────────────────────────────────────────────

class _NextTaskCard extends StatelessWidget {
  const _NextTaskCard({required this.task, required this.onStart});
  final UpcomingTask? task; final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = task; final hasTask = t != null && t.id > 0;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor)),
      child: Column(children: [
        Container(height: 88, width: double.infinity,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            gradient: LinearGradient(
                colors: [Color(0xFF2F5C55), Color(0xFF3D7A6F)])),
          child: Stack(children: [
            Positioned(top: 12, left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(7)),
                child: Text(t?.subjectTag ?? 'GENERAL',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 11,
                      color: Colors.black87)))),
            Positioned(bottom: 10, right: 14,
              child: Icon(Icons.menu_book,
                  color: Colors.white.withOpacity(0.2), size: 28)),
          ])),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t?.title ?? 'No upcoming task',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
                if (t != null && t.timeLabel.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(t.timeLabel, style: TextStyle(
                      color: cs.onSurface.withOpacity(0.5), fontSize: 12)),
                ],
                const SizedBox(height: 3),
                Text(t?.description ?? 'Track a note from Library.',
                  style: TextStyle(
                      color: cs.onSurface.withOpacity(0.5), fontSize: 12)),
              ])),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: hasTask ? onStart : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
              child: Text(hasTask ? 'Open' : 'No Task')),
          ])),
      ]));
  }
}

// ── Upcoming Tile ───────────────────────────────────────────────────

class _UpcomingTile extends StatelessWidget {
  const _UpcomingTile({required this.task, required this.onTap});
  final UpcomingTask task; final VoidCallback? onTap;

  Color _c(String t) => switch (t.toUpperCase()) {
    'QUIZ' => const Color(0xFFE5484D),
    'REVIEW' => const Color(0xFF4FA7A1),
    'DEEP_REVIEW' => const Color(0xFFF5A524),
    _ => AppColors.primary };

  IconData _i(String t) => switch (t.toUpperCase()) {
    'QUIZ' => Icons.quiz_outlined,
    'REVIEW' => Icons.style_outlined,
    'DEEP_REVIEW' => Icons.psychology_outlined,
    _ => Icons.menu_book_outlined };

  void _showInfo(BuildContext context) {
    final c = _c(task.taskType);
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(99))),
          const SizedBox(height: 16),
          Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(color: c.withOpacity(0.12),
                borderRadius: BorderRadius.circular(13)),
              child: Icon(_i(task.taskType), color: c, size: 21)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title, style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: c.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(6)),
                  child: Text(task.taskType, style: TextStyle(
                      color: c, fontWeight: FontWeight.w700, fontSize: 11))),
              ])),
          ]),
          const SizedBox(height: 14),
          _InfoRow(Icons.calendar_today_outlined, 'When',
            task.timeLabel.isNotEmpty ? task.timeLabel : 'Today'),
          if (task.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            _InfoRow(Icons.info_outline, 'Info', task.description),
          ],
          const SizedBox(height: 18),
          SizedBox(width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () { Navigator.pop(context); onTap?.call(); },
              icon: const Icon(Icons.calendar_today_outlined, size: 17),
              label: const Text('Open Study Planner'))),
        ])));
  }

  @override
  Widget build(BuildContext context) {
    final c = _c(task.taskType);
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _showInfo(context),
      borderRadius: BorderRadius.circular(13),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Theme.of(context).dividerColor)),
        child: Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(color: c.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(_i(task.taskType), color: c, size: 17)),
          const SizedBox(width: 11),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task.title, style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Row(children: [
                Icon(Icons.calendar_today_outlined,
                    size: 11, color: cs.onSurface.withOpacity(0.45)),
                const SizedBox(width: 3),
                Text(task.timeLabel.isNotEmpty ? task.timeLabel : 'Upcoming',
                  style: TextStyle(
                      color: cs.onSurface.withOpacity(0.45), fontSize: 11)),
                if (task.description.isNotEmpty) ...[
                  Text(' · ', style: TextStyle(
                      color: cs.onSurface.withOpacity(0.45), fontSize: 11)),
                  Expanded(child: Text(task.description,
                    style: TextStyle(
                        color: cs.onSurface.withOpacity(0.45), fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ]),
            ])),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: c.withOpacity(0.10),
              borderRadius: BorderRadius.circular(7)),
            child: Text(task.taskType, style: TextStyle(
                color: c, fontWeight: FontWeight.w700, fontSize: 10))),
          const SizedBox(width: 3),
          Icon(Icons.chevron_right,
              color: cs.onSurface.withOpacity(0.3), size: 16),
        ])));
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value);
  final IconData icon; final String label, value;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 15, color: AppColors.textSecondary),
      const SizedBox(width: 8),
      Text('$label: ', style: const TextStyle(
          fontWeight: FontWeight.w700, fontSize: 13)),
      Expanded(child: Text(value, style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
          fontSize: 13))),
    ]);
}

class _AiTip extends StatelessWidget {
  const _AiTip({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.8),
      borderRadius: BorderRadius.circular(18)),
    child: Row(children: [
      Container(width: 40, height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.lightbulb_outline,
            color: Colors.white, size: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('AI Study Tip', style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(message, style: TextStyle(
              color: Colors.white.withOpacity(0.92),
              height: 1.35, fontSize: 13)),
        ])),
    ]));
}
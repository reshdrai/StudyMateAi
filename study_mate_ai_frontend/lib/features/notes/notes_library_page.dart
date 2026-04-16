import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/config/routes.dart';
import '../shared/app_bottom_nav.dart';
import 'data/notes_repository.dart';
import 'model/note_item.dart';
import '../note_details/materials_study_page.dart';
import '../study_plan/study_plan_page.dart';
import '../../services/tracking_repository.dart';

class NotesLibraryPage extends StatefulWidget {
  const NotesLibraryPage({super.key});
  @override
  State<NotesLibraryPage> createState() => _NotesLibraryPageState();
}

class _NotesLibraryPageState extends State<NotesLibraryPage> {
  final _repo = NotesRepository();
  final _trackRepo = TrackingRepository();
  late Future<List<NoteItem>> _future;
  final _searchCtrl = TextEditingController();
  final Map<int, bool> _tracked = {};

  @override
  void initState() {
    super.initState();
    _reload();
    _loadTracking();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    _future = _repo.getNotes(category: 'All', query: _searchCtrl.text.trim());
    setState(() {});
  }

  Future<void> _loadTracking() async {
    try {
      final items = await _trackRepo.getAll();
      if (!mounted) return;
      setState(() {
        for (final i in items) _tracked[i.id] = i.isTracked;
      });
    } catch (_) {}
  }

  Future<void> _toggleTracking(int id) async {
    final cur = _tracked[id] ?? false;
    setState(() => _tracked[id] = !cur);
    try {
      final res = await _trackRepo.toggle(id);
      if (mounted) setState(() => _tracked[id] = res);
    } catch (_) {
      if (mounted) setState(() => _tracked[id] = cur);
    }
  }

  void _showTrackSheet() async {
    final items = await _trackRepo.getAll();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _TrackSheet(
        items: items,
        onToggle: (id) async {
          final r = await _trackRepo.toggle(id);
          if (mounted) setState(() => _tracked[id] = r);
          return r;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<NoteItem>>(
          future: _future,
          builder: (_, snap) {
            final notes = snap.data ?? [];
            return RefreshIndicator(
              onRefresh: () async {
                _reload();
                _loadTracking();
                await _future;
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 90),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Notes Library',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Upload notes and let AI analyze them',
                              style: TextStyle(
                                color: cs.onSurface.withOpacity(0.5),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _showTrackSheet,
                        icon: const Icon(Icons.track_changes, size: 17),
                        label: const Text('Track'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => _reload(),
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.search,
                        color: cs.onSurface.withOpacity(0.4),
                      ),
                      hintText: 'Search your notes...',
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (snap.connectionState == ConnectionState.waiting)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (notes.isEmpty)
                    _empty(context)
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: notes.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.74,
                          ),
                      itemBuilder: (_, i) {
                        final n = notes[i];
                        return _NoteCard(
                          note: n,
                          isTracked: _tracked[n.id] ?? false,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MaterialStudyPage(
                                materialId: n.id,
                                title: n.title,
                              ),
                            ),
                          ),
                          onStudyPlan: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StudyPlanPage(materialId: n.id),
                            ),
                          ),
                          onTrackToggle: () => _toggleTracking(n.id),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => context.push(AppRoutes.upload),
        icon: const Icon(Icons.add, size: 20),
        label: const Text(
          'Upload',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }

  Widget _empty(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 40),
    child: Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Icon(
            Icons.note_add_outlined,
            size: 32,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'No notes yet',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        const SizedBox(height: 8),
        const Text(
          'Upload a PDF or text file to get started.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: () => context.push(AppRoutes.upload),
          icon: const Icon(Icons.file_upload_outlined, size: 18),
          label: const Text('Upload Notes'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    ),
  );
}

// ── Track Sheet ──────────────────────────────────────────────────────

class _TrackSheet extends StatefulWidget {
  const _TrackSheet({required this.items, required this.onToggle});
  final List<TrackingItem> items;
  final Future<bool> Function(int) onToggle;
  @override
  State<_TrackSheet> createState() => _TrackSheetState();
}

class _TrackSheetState extends State<_TrackSheet> {
  late List<TrackingItem> _items;
  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, ctrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Track Notes',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Selected notes appear in Home & Analytics.',
                  style: TextStyle(
                    color: cs.onSurface.withOpacity(0.55),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                Text(
                  'If none selected, all notes are used.',
                  style: TextStyle(
                    color: AppColors.primary.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Text(
                      'No notes yet.',
                      style: TextStyle(color: cs.onSurface.withOpacity(0.5)),
                    ),
                  )
                : ListView.separated(
                    controller: ctrl,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final item = _items[i];
                      return InkWell(
                        onTap: () async {
                          final r = await widget.onToggle(item.id);
                          setState(() => _items[i].isTracked = r);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: item.isTracked
                                ? AppColors.primary.withOpacity(0.07)
                                : Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: item.isTracked
                                  ? AppColors.primary.withOpacity(0.35)
                                  : Theme.of(context).dividerColor,
                              width: item.isTracked ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: item.isTracked
                                      ? AppColors.primary.withOpacity(0.12)
                                      : cs.onSurface.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Icon(
                                  item.fileType.contains('pdf')
                                      ? Icons.picture_as_pdf_outlined
                                      : Icons.description_outlined,
                                  color: item.isTracked
                                      ? AppColors.primary
                                      : cs.onSurface.withOpacity(0.5),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: item.isTracked
                                        ? AppColors.primary
                                        : null,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 10),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: item.isTracked
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: item.isTracked
                                        ? AppColors.primary
                                        : cs.onSurface.withOpacity(0.4),
                                    width: 2,
                                  ),
                                ),
                                child: item.isTracked
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 14,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Note Card ────────────────────────────────────────────────────────

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.isTracked,
    required this.onTap,
    required this.onStudyPlan,
    required this.onTrackToggle,
  });
  final NoteItem note;
  final bool isTracked;
  final VoidCallback onTap, onStudyPlan, onTrackToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final statusColor = note.status == NoteStatus.aiReady
        ? AppColors.success
        : note.status == NoteStatus.analyzing
        ? AppColors.warning
        : AppColors.textSecondary;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isTracked
                ? AppColors.primary.withOpacity(0.45)
                : Theme.of(context).dividerColor,
            width: isTracked ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            note.type == NoteType.pdf
                                ? Icons.picture_as_pdf_outlined
                                : note.type == NoteType.image
                                ? Icons.image_outlined
                                : Icons.description_outlined,
                            size: 32,
                            color: AppColors.primary.withOpacity(0.7),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            note.typeLabel,
                            style: TextStyle(
                              color: cs.onSurface.withOpacity(0.5),
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (note.status != NoteStatus.none)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          note.status == NoteStatus.aiReady ? 'READY' : 'PROC.',
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ),
                  // Track toggle
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: onTrackToggle,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: isTracked
                              ? AppColors.primary
                              : Theme.of(context).cardColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isTracked
                                ? AppColors.primary
                                : cs.onSurface.withOpacity(0.25),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          isTracked ? Icons.check : Icons.add_chart,
                          size: 13,
                          color: isTracked
                              ? Colors.white
                              : cs.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                  // Study plan icon
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: GestureDetector(
                      onTap: onStudyPlan,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: cs.onSurface.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.calendar_today_outlined,
                          size: 13,
                          color: cs.onSurface.withOpacity(0.45),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              note.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              note.dateLabel,
              style: TextStyle(
                color: cs.onSurface.withOpacity(0.45),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

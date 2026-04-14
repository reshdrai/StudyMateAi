import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/config/routes.dart';
import 'data/notes_repository.dart';
import 'model/note_item.dart';
import '../note_details/materials_study_page.dart';

class NotesLibraryPage extends StatefulWidget {
  const NotesLibraryPage({super.key});

  @override
  State<NotesLibraryPage> createState() => _NotesLibraryPageState();
}

class _NotesLibraryPageState extends State<NotesLibraryPage> {
  final _repo = NotesRepository();

  late Future<List<NoteItem>> _future;
  final _searchCtrl = TextEditingController();

  final List<String> _tabs = ["All", "Comp Sci", "Calculus", "History"];
  String _activeTab = "All";

  int _navIndex = 1;

  @override
  void initState() {
    super.initState();
    _future = _repo.getNotes(category: _activeTab, query: "");
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _repo.getNotes(
        category: _activeTab,
        query: _searchCtrl.text.trim(),
      );
    });
  }

  void _onTabSelect(String tab) {
    setState(() => _activeTab = tab);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FutureBuilder<List<NoteItem>>(
          future: _future,
          builder: (context, snap) {
            final notes = snap.data ?? const <NoteItem>[];

            return RefreshIndicator(
              onRefresh: () async {
                _reload();
                await _future;
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 90),
                children: [
                  // ── Header ──
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "✦ AI ASSISTANT",
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const Spacer(),
                      _CircleIconButton(
                        icon: Icons.grid_view_rounded,
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Notes Library",
                    style:
                        TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Upload notes and let AI analyze them",
                    style: TextStyle(
                      color: AppColors.textSecondary.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 16),
                  _SearchBar(
                    controller: _searchCtrl,
                    onChanged: (_) => _reload(),
                  ),

                  const SizedBox(height: 14),
                  _CategoryChips(
                    tabs: _tabs,
                    active: _activeTab,
                    onSelect: _onTabSelect,
                  ),

                  const SizedBox(height: 16),

                  if (snap.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (notes.isEmpty)
                    _buildEmptyState()
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
                        childAspectRatio: 0.78,
                      ),
                      itemBuilder: (_, i) {
                        final n = notes[i];
                        return _NoteCard(
                          note: n,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MaterialStudyPage(
                                  materialId: n.id,
                                  title: n.title,
                                ),
                              ),
                            );
                          },
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

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _navIndex,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        onTap: (i) {
          setState(() => _navIndex = i);
          if (i == 0) context.go(AppRoutes.home);
          if (i == 1) context.go(AppRoutes.library);
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

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.note_add_outlined,
              size: 34,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "No notes yet",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Upload a PDF or text file to get started.\nAI will extract key points and create quizzes.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => context.push(AppRoutes.upload),
            icon: const Icon(Icons.file_upload_outlined, size: 18),
            label: const Text('Upload Notes'),
            style: ElevatedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════
// Sub-components
// ════════════════════════════════════════════

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.outline),
          ),
          child: Icon(icon, color: AppColors.textPrimary, size: 20),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
        hintText: "Search your notes...",
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.tabs,
    required this.active,
    required this.onSelect,
  });

  final List<String> tabs;
  final String active;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final t = tabs[i];
          final isActive = t == active;

          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onSelect(t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isActive ? AppColors.primary : AppColors.outline,
                ),
              ),
              child: Center(
                child: Text(
                  t,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isActive ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.onTap});
  final NoteItem note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusLabel = note.statusLabel;
    final hasStatus = statusLabel.isNotEmpty;

    final statusColor = note.status == NoteStatus.aiReady
        ? AppColors.success
        : note.status == NoteStatus.analyzing
            ? AppColors.warning
            : AppColors.textSecondary;

    final statusBg = statusColor.withOpacity(0.10);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.outline),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail area
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Stack(
                  children: [
                    // Status badge
                    if (hasStatus)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (note.status == NoteStatus.aiReady)
                                Icon(Icons.check_circle,
                                    size: 12, color: statusColor)
                              else if (note.status == NoteStatus.analyzing)
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                        statusColor),
                                  ),
                                ),
                              const SizedBox(width: 4),
                              Text(
                                note.status == NoteStatus.aiReady
                                    ? 'READY'
                                    : 'PROCESSING',
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 9,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // File type icon
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            note.type == NoteType.pdf
                                ? Icons.picture_as_pdf_outlined
                                : note.type == NoteType.image
                                    ? Icons.image_outlined
                                    : Icons.description_outlined,
                            size: 36,
                            color: AppColors.primary.withOpacity(0.7),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            note.typeLabel,
                            style: TextStyle(
                              color: AppColors.textSecondary.withOpacity(0.7),
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              note.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              "${note.dateLabel} • ${note.metaLabel}",
              style: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.7),
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

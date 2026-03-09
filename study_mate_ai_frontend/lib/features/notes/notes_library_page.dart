import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/config/routes.dart';
import 'data/notes_repository.dart';
import 'model/note_item.dart';

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

  int _navIndex = 1; // Library selected

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

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 90),
              children: [
                Row(
                  children: [
                    const Text(
                      "✦ AI ASSISTANT",
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    _CircleIconButton(
                      icon: Icons.grid_view_rounded,
                      onTap: () {
                        // ✅ future: switch grid/list mode
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                const Text(
                  "Notes Library",
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                ),

                const SizedBox(height: 14),
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

                const SizedBox(height: 14),

                if (snap.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.only(top: 30),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (notes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 30),
                    child: Column(
                      children: const [
                        Icon(
                          Icons.note_alt_outlined,
                          size: 44,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(height: 10),
                        Text(
                          "No notes found",
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        SizedBox(height: 6),
                        Text(
                          "Try another category or search keyword.",
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: notes.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.78,
                        ),
                    itemBuilder: (_, i) {
                      final n = notes[i];
                      return _NoteCard(
                        note: n,
                        onTap: () {
                          // ✅ future: open note detail screen
                          // context.push('/notes/${n.id}');
                        },
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () {
          // ✅ future: create/upload note
          context.push(AppRoutes.upload);
        },
        child: const Icon(Icons.add),
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _navIndex,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        onTap: (i) {
          setState(() => _navIndex = i);
          // ✅ WHEN OTHER SCREENS READY:
          // if (i == 0) context.go(AppRoutes.home);
          // if (i == 1) context.go('/library');
          // if (i == 2) context.go('/schedule');
          // if (i == 3) context.go('/settings');
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

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 1.2,
      shadowColor: Colors.black12,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: AppColors.textPrimary),
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
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final t = tabs[i];
          final isActive = t == active;

          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onSelect(t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                    fontWeight: FontWeight.w800,
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
    final badge = note.statusLabel;
    final badgeColor = note.status == NoteStatus.aiReady
        ? AppColors.primary
        : (note.status == NoteStatus.analyzing
              ? const Color(0xFFF59E0B)
              : AppColors.textSecondary);

    final badgeBg = note.status == NoteStatus.aiReady
        ? AppColors.primary.withOpacity(0.12)
        : (note.status == NoteStatus.analyzing
              ? const Color(0xFFF59E0B).withOpacity(0.12)
              : AppColors.surfaceSoft);

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
            // thumbnail area
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        margin: const EdgeInsets.all(10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            color: badgeColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: note.previewImagePath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.asset(
                                note.previewImagePath!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  note.type == NoteType.pdf
                                      ? Icons.picture_as_pdf_outlined
                                      : (note.type == NoteType.image
                                            ? Icons.image_outlined
                                            : Icons.description_outlined),
                                  size: 40,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  note.typeLabel,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w700,
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
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              "${note.dateLabel} • ${note.metaLabel}",
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

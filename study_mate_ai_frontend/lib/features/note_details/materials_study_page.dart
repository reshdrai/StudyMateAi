import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../shared/ai_widgets.dart';
import './study_ai_repository.dart';
import './study_models.dart';
import '../quiz/quiz_page.dart';
import '../study_plan/study_plan_page.dart';

class MaterialStudyPage extends StatefulWidget {
  final int materialId;
  final String title;
  const MaterialStudyPage({
    super.key,
    required this.materialId,
    required this.title,
  });

  @override
  State<MaterialStudyPage> createState() => _MaterialStudyPageState();
}

class _MaterialStudyPageState extends State<MaterialStudyPage> {
  final _repo = StudyAiRepository();
  bool _loading = false;
  bool _hasError = false;
  String _errorMsg = '';
  OverviewResponse? _overview;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final data = await _repo.generateOverview(widget.materialId);
      if (!mounted) return;
      setState(() => _overview = data);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMsg = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goStudyPlan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudyPlanPage(materialId: widget.materialId),
      ),
    );
  }

  /// Show quiz choice modal when user taps a topic card
  void _showQuizChoice(String topicName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outline,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 20),
            Icon(Icons.quiz_outlined, size: 36, color: AppColors.primary),
            const SizedBox(height: 12),
            const Text(
              'Generate Quiz',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose quiz scope',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),

            // This topic only
            _QuizChoiceTile(
              icon: Icons.filter_alt_outlined,
              title: topicName,
              subtitle: '3-4 focused questions on this topic',
              color: AppColors.primary,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuizPage(
                      materialId: widget.materialId,
                      topicLabel: topicName,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // All topics
            _QuizChoiceTile(
              icon: Icons.all_inclusive,
              title: 'All Topics',
              subtitle: 'Comprehensive quiz across all topics',
              color: AppColors.tealAccent,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuizPage(materialId: widget.materialId),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.background,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 56, bottom: 14),
              title: Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (_loading)
            SliverFillRemaining(child: _loadingState())
          else if (_hasError)
            SliverFillRemaining(child: _errorState())
          else if (_overview == null)
            SliverFillRemaining(child: _emptyState())
          else
            ..._content(),
        ],
      ),
    );
  }

  Widget _loadingState() => const SingleChildScrollView(
    padding: EdgeInsets.all(18),
    child: AiProcessingIndicator(
      message: 'Analyzing your notes',
      subMessage: 'Extracting topics and key points',
    ),
  );

  Widget _errorState() => AiEmptyState(
    icon: Icons.error_outline,
    title: 'Analysis failed',
    subtitle: _errorMsg.length > 100
        ? '${_errorMsg.substring(0, 100)}...'
        : _errorMsg,
    buttonLabel: 'Retry',
    onButton: _generate,
  );

  Widget _emptyState() => AiEmptyState(
    icon: Icons.auto_awesome_outlined,
    title: 'Ready to analyze',
    subtitle: 'Tap to extract key points and topics.',
    buttonLabel: 'Generate Overview',
    onButton: _generate,
  );

  List<Widget> _content() {
    final o = _overview!;
    return [
      // Banner
      SliverToBoxAdapter(
        child: _Banner(
          flashcards: o.flashcards.length,
          topics: o.importantTopics.length,
        ),
      ),

      // Flashcards
      if (o.flashcards.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
            child: AiSectionHeader(
              title: 'Key Points',
              subtitle: '${o.flashcards.length} flashcards',
              icon: Icons.lightbulb_outline,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 190,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: o.flashcards.length,
              itemBuilder: (_, i) => _FlashCard(
                card: o.flashcards[i],
                index: i,
                total: o.flashcards.length,
              ),
            ),
          ),
        ),
      ],

      // Important Topics — tap to open quiz choice modal
      if (o.importantTopics.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 0),
            child: AiSectionHeader(
              title: 'Important Topics',
              subtitle: 'Tap a topic to generate quiz',
              icon: Icons.bar_chart_rounded,
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: _TopicCard(
                topic: o.importantTopics[i],
                rank: i + 1,
                onTap: () => _showQuizChoice(o.importantTopics[i].topic),
              ),
            ),
            childCount: o.importantTopics.length,
          ),
        ),
      ],

      // Study Plan action
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 28, 18, 8),
          child: AiSectionHeader(
            title: 'Next Steps',
            showAiBadge: false,
            icon: Icons.rocket_launch_outlined,
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: _ActionCard(
            icon: Icons.calendar_today_outlined,
            label: 'Generate Study Plan',
            description: 'AI-optimized schedule based on your topics',
            color: AppColors.tealAccent,
            onTap: _goStudyPlan,
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 32)),
    ];
  }
}

// ═══════════════════ Sub-widgets ═══════════════════

class _QuizChoiceTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuizChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final int flashcards, topics;
  const _Banner({required this.flashcards, required this.topics});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Analysis Complete',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$flashcards flashcards  •  $topics topics identified',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: Colors.white.withOpacity(0.8)),
        ],
      ),
    );
  }
}

class _FlashCard extends StatefulWidget {
  final FlashcardItem card;
  final int index, total;
  const _FlashCard({
    required this.card,
    required this.index,
    required this.total,
  });

  @override
  State<_FlashCard> createState() => _FlashCardState();
}

class _FlashCardState extends State<_FlashCard> {
  bool _flipped = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _flipped = !_flipped),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Container(
          key: ValueKey(_flipped),
          width: 260,
          margin: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _flipped
                ? AppColors.primary.withOpacity(0.06)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _flipped
                  ? AppColors.primary.withOpacity(0.3)
                  : AppColors.outline,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _flipped
                          ? AppColors.primary.withOpacity(0.12)
                          : AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _flipped ? 'ANSWER' : 'QUESTION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: _flipped
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${widget.index + 1}/${widget.total}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Text(
                  _flipped ? widget.card.back : widget.card.front,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: _flipped ? FontWeight.w500 : FontWeight.w700,
                    height: 1.4,
                  ),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.touch_app_outlined,
                    size: 13,
                    color: AppColors.textSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Tap to ${_flipped ? "see question" : "reveal answer"}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  final TopicPriorityItem topic;
  final int rank;
  final VoidCallback onTap;

  const _TopicCard({
    required this.topic,
    required this.rank,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '#$rank',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.topic,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (topic.subtopics.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        topic.subtopics.take(3).join(' • '),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              PriorityBadge(priority: topic.priority),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label, description;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.outline),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color, size: 22),
          ],
        ),
      ),
    );
  }
}

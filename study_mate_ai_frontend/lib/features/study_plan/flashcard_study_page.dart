import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/theme/app_colors.dart';
import '../../services/token_storage.dart';
import '../../services/api_config.dart';
import '../shared/ai_widgets.dart';
import '../quiz/quiz_page.dart';
import '../study_plan/study_plan_repository.dart';

/// Opened when user taps a READ/REVIEW/DEEP_REVIEW task in the study plan.
/// Shows topic flashcards one-by-one, then offers to take a quiz.
/// Returns true if the scheduler task was completed.
class FlashcardStudyPage extends StatefulWidget {
  final int materialId;
  final String topic;
  final int? schedulerTaskId;

  const FlashcardStudyPage({
    super.key,
    required this.materialId,
    required this.topic,
    this.schedulerTaskId,
  });

  @override
  State<FlashcardStudyPage> createState() => _FlashcardStudyPageState();
}

class _FlashcardStudyPageState extends State<FlashcardStudyPage> {
  final _planRepo = StudyPlanRepository();
  final _pageController = PageController();

  bool _loading = true;
  String? _error;
  List<_Flashcard> _cards = [];
  int _currentIndex = 0;
  final Set<int> _flipped = {};
  bool _taskDone = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await TokenStorage.getToken();
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/api/materials/${widget.materialId}/flashcards'
        '?topic=${Uri.encodeComponent(widget.topic)}',
      );
      final res = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 20));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (data['flashcards'] as List?) ?? [];
        final cards = list
            .map(
              (e) => _Flashcard(front: e['front'] ?? '', back: e['back'] ?? ''),
            )
            .where((c) => c.front.isNotEmpty && c.back.isNotEmpty)
            .toList();
        if (!mounted) return;
        setState(() {
          _cards = cards;
          _loading = false;
        });
      } else {
        throw Exception('Server error ${res.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _markTaskDone() async {
    if (widget.schedulerTaskId == null || _taskDone) return;
    try {
      await _planRepo.toggleTask(widget.schedulerTaskId!, true);
      _taskDone = true;
    } catch (_) {}
  }

  Future<void> _openQuiz() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => QuizPage(
          materialId: widget.materialId,
          topicLabel: widget.topic,
          schedulerTaskId: widget.schedulerTaskId,
        ),
      ),
    );
    if (result == true && mounted) {
      _taskDone = true;
      Navigator.pop(context, true);
    }
  }

  Future<void> _markDoneWithoutQuiz() async {
    await _markTaskDone();
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _taskDone);
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context, _taskDone),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.topic,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (_cards.isNotEmpty)
                Text(
                  '${_currentIndex + 1} / ${_cards.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          actions: [
            if (_cards.isNotEmpty)
              TextButton(
                onPressed: _openQuiz,
                child: const Text(
                  'Skip to Quiz',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: AiProcessingIndicator(
          message: 'Loading flashcards',
          subMessage: 'Finding cards for this topic',
        ),
      );
    }

    if (_error != null) {
      return AiEmptyState(
        icon: Icons.error_outline,
        title: 'Could not load flashcards',
        subtitle: _error!.length > 100
            ? '${_error!.substring(0, 100)}...'
            : _error!,
        buttonLabel: 'Retry',
        onButton: _load,
      );
    }

    if (_cards.isEmpty) {
      return AiEmptyState(
        icon: Icons.style_outlined,
        title: 'No flashcards for this topic',
        subtitle: 'Go straight to the quiz to practice.',
        buttonLabel: 'Start Quiz',
        onButton: _openQuiz,
      );
    }

    return Column(
      children: [
        // Progress bar
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentIndex + 1) / _cards.length,
              backgroundColor: AppColors.outline,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              minHeight: 5,
            ),
          ),
        ),

        // Cards
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _cards.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (_, i) => _CardWidget(
              card: _cards[i],
              index: i,
              total: _cards.length,
              flipped: _flipped.contains(i),
              onFlip: () => setState(() {
                _flipped.contains(i) ? _flipped.remove(i) : _flipped.add(i);
              }),
            ),
          ),
        ),

        // Bottom controls
        Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.outline)),
          ),
          child: Column(
            children: [
              // Prev / Next nav
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: _currentIndex > 0
                        ? () => _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          )
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        _flipped.contains(_currentIndex)
                            ? 'Tap card to see question'
                            : 'Tap card to reveal answer',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: _currentIndex < _cards.length - 1
                        ? () => _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          )
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // On last card show big Quiz button, otherwise show Mark Done + Take Quiz
              if (_currentIndex == _cards.length - 1)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openQuiz,
                    icon: const Icon(Icons.quiz_rounded),
                    label: const Text('Start Quiz to Complete Task'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _markDoneWithoutQuiz,
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Mark Done'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _openQuiz,
                        icon: const Icon(Icons.quiz_outlined, size: 16),
                        label: const Text('Take Quiz'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Models & Card Widget ───────────────────────────────────────────

class _Flashcard {
  final String front, back;
  const _Flashcard({required this.front, required this.back});
}

class _CardWidget extends StatelessWidget {
  final _Flashcard card;
  final int index, total;
  final bool flipped;
  final VoidCallback onFlip;

  const _CardWidget({
    required this.card,
    required this.index,
    required this.total,
    required this.flipped,
    required this.onFlip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: GestureDetector(
        onTap: onFlip,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: Tween(begin: 0.95, end: 1.0).animate(anim),
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: Container(
            key: ValueKey('${index}_$flipped'),
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: flipped
                    ? [AppColors.primary, AppColors.primary.withOpacity(0.8)]
                    : [AppColors.surface, AppColors.surfaceSoft],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: flipped ? AppColors.primary : AppColors.outline,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: flipped
                      ? AppColors.primary.withOpacity(0.2)
                      : Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Pill(
                      label: flipped ? 'ANSWER' : 'QUESTION',
                      color: flipped
                          ? Colors.white.withOpacity(0.25)
                          : AppColors.primary.withOpacity(0.12),
                      textColor: flipped ? Colors.white : AppColors.primary,
                    ),
                    const Spacer(),
                    _Pill(
                      label: '${index + 1} / $total',
                      color: flipped
                          ? Colors.white.withOpacity(0.15)
                          : AppColors.surfaceSoft,
                      textColor: flipped
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Text(
                        flipped ? card.back : card.front,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: flipped
                              ? FontWeight.w500
                              : FontWeight.w800,
                          height: 1.4,
                          color: flipped ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app_outlined,
                        size: 14,
                        color: flipped
                            ? Colors.white.withOpacity(0.6)
                            : AppColors.textSecondary.withOpacity(0.5),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        flipped ? 'Tap to flip back' : 'Tap to reveal',
                        style: TextStyle(
                          fontSize: 12,
                          color: flipped
                              ? Colors.white.withOpacity(0.6)
                              : AppColors.textSecondary.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color, textColor;
  const _Pill({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: textColor,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/theme/app_colors.dart';
import '../../services/token_storage.dart';
import '../../services/api_config.dart';
import '../shared/ai_widgets.dart';
import '../quiz/quiz_page.dart';
import '../study_plan/study_plan_repository.dart';

/// Opens when a READ task from the scheduler is tapped.
/// Shows big topic-focused flashcards one-at-a-time, then auto-launches
/// a quiz for that topic. When the quiz finishes, the scheduler task
/// is marked complete and this page closes with true.
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
  final PageController _pageController = PageController();
  final _planRepo = StudyPlanRepository();

  bool _loading = true;
  String? _error;
  List<_Flashcard> _flashcards = [];
  int _currentIndex = 0;
  final Set<int> _flippedCards = {};
  bool _taskMarkedDone = false;

  @override
  void initState() {
    super.initState();
    _loadFlashcards();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadFlashcards() async {
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
          .timeout(const Duration(seconds: 30));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (data['flashcards'] as List?) ?? [];
        final cards = list
            .map(
              (e) => _Flashcard(
                front: (e['front'] ?? '').toString(),
                back: (e['back'] ?? '').toString(),
              ),
            )
            .where((c) => c.front.isNotEmpty && c.back.isNotEmpty)
            .toList();

        if (!mounted) return;
        setState(() {
          _flashcards = cards;
          _loading = false;
        });
      } else {
        throw Exception('Status ${res.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _flipCard(int index) {
    setState(() {
      if (_flippedCards.contains(index)) {
        _flippedCards.remove(index);
      } else {
        _flippedCards.add(index);
      }
    });
  }

  Future<void> _startQuiz() async {
    // Navigate to quiz, passing schedulerTaskId so it auto-completes the task
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => QuizPage(
          materialId: widget.materialId,
          topicLabel: widget.topic,
          schedulerTaskId: widget.schedulerTaskId,
          attemptNumber: 1,
        ),
      ),
    );

    if (result == true) {
      _taskMarkedDone = true;
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _skipToQuiz() async {
    await _startQuiz();
  }

  /// Mark the READ task complete without taking a quiz
  Future<void> _markDoneWithoutQuiz() async {
    if (widget.schedulerTaskId == null) {
      Navigator.pop(context, false);
      return;
    }
    try {
      await _planRepo.toggleTask(widget.schedulerTaskId!, true);
      _taskMarkedDone = true;
    } catch (_) {}
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _taskMarkedDone);
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context, _taskMarkedDone),
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
              if (_flashcards.isNotEmpty)
                Text(
                  'Card ${_currentIndex + 1} of ${_flashcards.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          actions: [
            if (_flashcards.isNotEmpty)
              TextButton(
                onPressed: _skipToQuiz,
                child: const Text(
                  'Skip to quiz',
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
          subMessage: 'Preparing your study session',
        ),
      );
    }

    if (_error != null) {
      return AiEmptyState(
        icon: Icons.error_outline,
        title: 'Could not load flashcards',
        subtitle: _error!.length > 80
            ? '${_error!.substring(0, 80)}...'
            : _error!,
        buttonLabel: 'Retry',
        onButton: _loadFlashcards,
      );
    }

    if (_flashcards.isEmpty) {
      return AiEmptyState(
        icon: Icons.style_outlined,
        title: 'No flashcards for this topic',
        subtitle: 'You can go straight to the quiz.',
        buttonLabel: 'Start Quiz',
        onButton: _startQuiz,
      );
    }

    return Column(
      children: [
        // Progress bar
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentIndex + 1) / _flashcards.length,
              backgroundColor: AppColors.outline,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              minHeight: 6,
            ),
          ),
        ),

        // Swipeable flashcards
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _flashcards.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (_, i) => _BigFlashcard(
              card: _flashcards[i],
              index: i,
              total: _flashcards.length,
              flipped: _flippedCards.contains(i),
              onFlip: () => _flipCard(i),
            ),
          ),
        ),

        // Bottom controls
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.outline)),
          ),
          child: Column(
            children: [
              // Nav row
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
                        _flippedCards.contains(_currentIndex)
                            ? 'Tap card to see question'
                            : 'Tap card to reveal answer',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: _currentIndex < _flashcards.length - 1
                        ? () => _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          )
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Primary action: after last card => big "Start Quiz" button
              if (_currentIndex == _flashcards.length - 1)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _startQuiz,
                    icon: const Icon(Icons.quiz_rounded),
                    label: const Text('Start Quiz to Complete Task'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Mark Done'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _startQuiz,
                        icon: const Icon(Icons.quiz_outlined, size: 18),
                        label: const Text('Take Quiz'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
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

class _Flashcard {
  final String front, back;
  _Flashcard({required this.front, required this.back});
}

class _BigFlashcard extends StatelessWidget {
  final _Flashcard card;
  final int index, total;
  final bool flipped;
  final VoidCallback onFlip;

  const _BigFlashcard({
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
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, anim) {
            return ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(anim),
              child: FadeTransition(opacity: anim, child: child),
            );
          },
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
                      ? AppColors.primary.withOpacity(0.25)
                      : Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Label
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: flipped
                            ? Colors.white.withOpacity(0.25)
                            : AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        flipped ? 'ANSWER' : 'QUESTION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: flipped ? Colors.white : AppColors.primary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: flipped
                            ? Colors.white.withOpacity(0.15)
                            : AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${index + 1} / $total',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: flipped
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Main content - centered
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Text(
                        flipped ? card.back : card.front,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: flipped
                              ? FontWeight.w600
                              : FontWeight.w800,
                          height: 1.4,
                          color: flipped ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Tap hint
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app_outlined,
                        size: 16,
                        color: flipped
                            ? Colors.white.withOpacity(0.7)
                            : AppColors.textSecondary.withOpacity(0.6),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        flipped ? 'Tap to flip back' : 'Tap to reveal',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: flipped
                              ? Colors.white.withOpacity(0.7)
                              : AppColors.textSecondary.withOpacity(0.6),
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

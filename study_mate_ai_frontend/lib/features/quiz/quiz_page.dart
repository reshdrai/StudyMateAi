import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../shared/ai_widgets.dart';
import '../note_details/study_ai_repository.dart';
import '../note_details/study_models.dart';
import '../study_plan/study_plan_page.dart';

class QuizPage extends StatefulWidget {
  final int materialId;
  final String? topicLabel; // null = all topics

  const QuizPage({super.key, required this.materialId, this.topicLabel});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final _repo = StudyAiRepository();
  bool _loading = true;
  QuizResponse? _quiz;
  int _current = 0;
  final Map<int, String> _answers = {};
  bool _submitted = false;
  QuizResult? _result;

  String get _topicDisplay => widget.topicLabel ?? 'All Topics';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      QuizResponse data;
      if (widget.topicLabel != null) {
        // Request 3-4 questions per topic
        data = await _repo.generateQuizForTopic(
          widget.materialId,
          widget.topicLabel!,
          maxQuestions: 4,
        );
      } else {
        data = await _repo.generateQuiz(widget.materialId);
      }
      if (!mounted) return;
      setState(() {
        _quiz = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _select(int qi, String answer) {
    if (_submitted) return;
    setState(() => _answers[qi] = answer);
  }

  Future<void> _submit() async {
    if (_quiz == null) return;
    final ans = <String, String>{};
    for (int i = 0; i < _quiz!.questions.length; i++) {
      ans[_quiz!.questions[i].question] = _answers[i] ?? '';
    }
    try {
      final r = await _repo.submitQuiz(widget.materialId, ans);
      if (!mounted) return;
      setState(() {
        _submitted = true;
        _result = r;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('Quiz: $_topicDisplay'),
          backgroundColor: AppColors.background,
        ),
        body: const Center(
          child: AiProcessingIndicator(
            message: 'Generating quiz',
            subMessage: 'Creating questions from your notes',
          ),
        ),
      );
    }

    if (_quiz == null || _quiz!.questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('Quiz: $_topicDisplay'),
          backgroundColor: AppColors.background,
        ),
        body: AiEmptyState(
          icon: Icons.quiz_outlined,
          title: 'No questions',
          subtitle: 'Could not generate quiz for this topic.',
          buttonLabel: 'Go Back',
          onButton: () => Navigator.pop(context),
        ),
      );
    }

    if (_submitted && _result != null) return _resultScreen();
    return _quizScreen();
  }

  Widget _quizScreen() {
    final q = _quiz!.questions[_current];
    final total = _quiz!.questions.length;
    final selected = _answers[_current];
    final allDone = _answers.length == total;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Quiz: $_topicDisplay'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Question ${_current + 1} of $total',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '${_answers.length}/$total answered',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_current + 1) / total,
                      backgroundColor: AppColors.outline,
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.primary,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),

            // Question + options - FIXED: wrapped in Expanded + SingleChildScrollView
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Topic badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        q.topic.isNotEmpty ? q.topic : _topicDisplay,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      q.question,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...q.options.asMap().entries.map((e) {
                      final idx = e.key;
                      final opt = e.value;
                      final letter = String.fromCharCode(65 + idx);
                      final isSel = selected == opt;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: () => _select(_current, opt),
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? AppColors.primary.withOpacity(0.08)
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSel
                                    ? AppColors.primary
                                    : AppColors.outline,
                                width: isSel ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: isSel
                                        ? AppColors.primary
                                        : AppColors.surfaceSoft,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      letter,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: isSel
                                            ? Colors.white
                                            : AppColors.textSecondary,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    opt,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSel
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                                if (isSel)
                                  const Icon(
                                    Icons.check_circle,
                                    color: AppColors.primary,
                                    size: 22,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    // Extra bottom padding so content doesn't hide behind nav
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Navigation buttons
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.outline)),
              ),
              child: Row(
                children: [
                  if (_current > 0)
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _current--),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Prev'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (_current < total - 1)
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _current++),
                      icon: const Text('Next'),
                      label: const Icon(Icons.arrow_forward, size: 18),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: allDone ? _submit : null,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Submit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: allDone
                            ? AppColors.success
                            : AppColors.outline,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════ QUIZ RESULTS SCREEN (matches your screenshot) ══════════════
  Widget _resultScreen() {
    final r = _result!;
    final good = r.scorePercent >= 60;
    final totalQ = r.totalQuestions;
    final correctQ = r.correctAnswers;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.share_outlined), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const Text(
              'Quiz Results',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 24),

            // Score circle
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CircularProgressIndicator(
                      value: r.scorePercent / 100,
                      strokeWidth: 10,
                      backgroundColor: AppColors.outline,
                      valueColor: AlwaysStoppedAnimation(
                        good ? AppColors.primary : AppColors.warning,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${r.scorePercent.round()}%',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'SCORE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Text(
              good ? 'Great job!' : 'Keep practicing!',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              "You've completed the quiz on $_topicDisplay",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 20),

            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatChip(
                  label: 'TIME TAKEN',
                  value:
                      '${(totalQ * 45 ~/ 60)}:${(totalQ * 45 % 60).toString().padLeft(2, '0')}',
                ),
                _StatChip(label: 'CORRECT', value: '$correctQ/$totalQ'),
                _StatChip(
                  label: 'RANK',
                  value: good
                      ? '#1'
                      : '#${(100 - r.scorePercent.round()) ~/ 10 + 1}',
                ),
              ],
            ),

            const SizedBox(height: 20),

            // AI Insights card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'AI Insights',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (r.weakTopics.isEmpty)
                    const Text(
                      'You performed well across all topics. Keep up the consistent study habits!',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    )
                  else ...[
                    Text(
                      'You struggled with ${r.weakTopics.length} topic${r.weakTopics.length > 1 ? 's' : ''}:',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...r.weakTopics.map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 6,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Review $t',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Focus areas
            if (r.weakTopics.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'FOCUS AREAS FOR NEXT SESSION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: r.weakTopics
                    .map(
                      (t) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.outline),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 8,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              t,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
            ],

            // Action buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _submitted = false;
                    _result = null;
                    _answers.clear();
                    _current = 0;
                    _loading = true;
                  });
                  _load();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Review Mistakes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        StudyPlanPage(materialId: widget.materialId),
                  ),
                ),
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Deep Dive with AI'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Maybe later'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

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
        data = await _repo.generateQuizForTopic(
          widget.materialId,
          widget.topicLabel!,
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
        body: Center(
          child: AiProcessingIndicator(
            message: 'Generating quiz',
            subMessage: 'Creating questions for $_topicDisplay',
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
            // Progress
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

            // Question + options
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
                  ],
                ),
              ),
            ),

            // Navigation
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

  Widget _resultScreen() {
    final r = _result!;
    final good = r.scorePercent >= 60;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: good
                        ? [
                            AppColors.success,
                            AppColors.success.withOpacity(0.7),
                          ]
                        : [
                            AppColors.warning,
                            AppColors.warning.withOpacity(0.7),
                          ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (good ? AppColors.success : AppColors.warning)
                          .withOpacity(0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${r.scorePercent.round()}%',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Score',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                good ? 'Great job!' : 'Keep practicing!',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${r.correctAnswers} out of ${r.totalQuestions} correct',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),

              if (r.weakTopics.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.warning.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.warning,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Topics to review',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: r.weakTopics
                            .map(
                              (t) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.warning.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  t,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          StudyPlanPage(materialId: widget.materialId),
                    ),
                  ),
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: const Text('Generate Study Plan'),
                  style: ElevatedButton.styleFrom(
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
                  onPressed: () => setState(() {
                    _submitted = false;
                    _result = null;
                    _answers.clear();
                    _current = 0;
                  }),
                  icon: const Icon(Icons.replay),
                  label: const Text('Retry Quiz'),
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
                child: const Text('Back to Overview'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

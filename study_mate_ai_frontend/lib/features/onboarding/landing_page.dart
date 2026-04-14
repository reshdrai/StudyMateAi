import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/routes.dart';
import '../../core/theme/app_colors.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingSlide> _slides = [
    _OnboardingSlide(
      icon: Icons.auto_awesome,
      iconBg: AppColors.primary,
      title: 'Study Smarter,\nNot Harder',
      subtitle:
          'Your AI-powered companion for mastering lectures, organizing notes, and acing your exams.',
      bgDecoration: _SlideDecoration.aiStars,
    ),
    _OnboardingSlide(
      icon: Icons.quiz_outlined,
      iconBg: AppColors.tealAccent,
      title: 'AI-Generated\nQuizzes',
      subtitle:
          'Upload your notes and get instant quizzes tailored to your weak areas. Practice smarter with adaptive questions.',
      bgDecoration: _SlideDecoration.quiz,
    ),
    _OnboardingSlide(
      icon: Icons.calendar_month_outlined,
      iconBg: Colors.orange,
      title: 'Smart Study\nScheduler',
      subtitle:
          'Our genetic algorithm builds the perfect study plan based on your priorities, weak topics, and available time.',
      bgDecoration: _SlideDecoration.calendar,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      context.go(AppRoutes.auth);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            children: [
              // Top bar
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'StudyMateAI',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.auth),
                    child: const Text('Skip'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Page view with slides
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (_, i) => _SlideWidget(slide: _slides[i]),
                ),
              ),

              const SizedBox(height: 18),

              // Dots indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _slides.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _currentPage ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _currentPage
                          ? AppColors.primary
                          : AppColors.outline,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  child: Text(
                    _currentPage == _slides.length - 1 ? 'Get Started' : 'Next',
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('I already have an account  '),
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.auth),
                    child: const Text(
                      'Log In',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
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

enum _SlideDecoration { aiStars, quiz, calendar }

class _OnboardingSlide {
  final IconData icon;
  final Color iconBg;
  final String title, subtitle;
  final _SlideDecoration bgDecoration;

  const _OnboardingSlide({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.bgDecoration,
  });
}

class _SlideWidget extends StatelessWidget {
  final _OnboardingSlide slide;

  const _SlideWidget({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  slide.iconBg.withOpacity(0.15),
                  slide.iconBg.withOpacity(0.05),
                ],
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background decorations
                ..._buildDecorations(slide.bgDecoration, slide.iconBg),
                // Center icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: slide.iconBg.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: slide.iconBg.withOpacity(0.2),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Icon(slide.icon, size: 50, color: slide.iconBg),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          slide.title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Text(
          slide.subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildDecorations(_SlideDecoration type, Color color) {
    switch (type) {
      case _SlideDecoration.aiStars:
        return [
          Positioned(
            top: 30,
            left: 30,
            child: _FloatingIcon(Icons.star, color, 20),
          ),
          Positioned(
            top: 60,
            right: 40,
            child: _FloatingIcon(Icons.auto_awesome, color, 16),
          ),
          Positioned(
            bottom: 50,
            left: 50,
            child: _FloatingIcon(Icons.lightbulb_outline, color, 18),
          ),
          Positioned(
            bottom: 80,
            right: 30,
            child: _FloatingIcon(Icons.psychology, color, 22),
          ),
          Positioned(
            top: 100,
            left: 80,
            child: _FloatingIcon(Icons.star_border, color, 14),
          ),
        ];
      case _SlideDecoration.quiz:
        return [
          Positioned(
            top: 40,
            left: 20,
            child: _FloatingIcon(Icons.check_circle_outline, color, 20),
          ),
          Positioned(
            top: 70,
            right: 30,
            child: _FloatingIcon(Icons.help_outline, color, 18),
          ),
          Positioned(
            bottom: 60,
            left: 40,
            child: _FloatingIcon(Icons.school, color, 22),
          ),
          Positioned(
            bottom: 40,
            right: 50,
            child: _FloatingIcon(Icons.grade, color, 16),
          ),
        ];
      case _SlideDecoration.calendar:
        return [
          Positioned(
            top: 30,
            left: 40,
            child: _FloatingIcon(Icons.event, color, 18),
          ),
          Positioned(
            top: 80,
            right: 30,
            child: _FloatingIcon(Icons.schedule, color, 20),
          ),
          Positioned(
            bottom: 50,
            left: 30,
            child: _FloatingIcon(Icons.trending_up, color, 22),
          ),
          Positioned(
            bottom: 70,
            right: 40,
            child: _FloatingIcon(Icons.task_alt, color, 16),
          ),
        ];
    }
  }
}

class _FloatingIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _FloatingIcon(this.icon, this.color, this.size);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color.withOpacity(0.5), size: size),
    );
  }
}

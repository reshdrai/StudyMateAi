import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/routes.dart';
import '../../core/theme/app_colors.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            children: [
              // Top bar: logo + skip
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
                    "StudyMateAI",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.auth),
                    child: const Text("Skip"),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Expanded(
                child: Container(
                  width: double.infinity,

                  // decoration: BoxDecoration(
                  //   color: AppColors.tealAccent.withOpacity(0.25),
                  //   borderRadius: BorderRadius.circular(24),
                  // ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      "assets/images/container.png",
                      // 👈 keeps aspect ratio
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                "Study Smarter,\nNot Harder",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              const Text(
                "Your AI-powered companion for mastering lectures, organizing notes, and acing your exams.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 18),

              // Dots indicator (simple)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _dot(active: true),
                  _dot(active: false),
                  _dot(active: false),
                ],
              ),

              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go(AppRoutes.auth),
                  child: const Text("Get Started"),
                ),
              ),

              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("I already have an account  "),
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.auth),
                    child: const Text(
                      "Log In",
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

  static Widget _dot({required bool active}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: active ? 18 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : AppColors.outline,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

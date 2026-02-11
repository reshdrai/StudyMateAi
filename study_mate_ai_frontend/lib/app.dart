import 'package:flutter/material.dart';
import 'core/config/routes.dart';
import 'core/theme/app_theme.dart';

class StudyMateApp extends StatelessWidget {
  const StudyMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'StudyMateAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: AppRoutes.router,
    );
  }
}

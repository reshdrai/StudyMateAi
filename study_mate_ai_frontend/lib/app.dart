import 'package:flutter/material.dart';
import 'core/config/routes.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';

class StudyMateApp extends StatelessWidget {
  const StudyMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder rebuilds MaterialApp.router whenever
    // themeProvider.toggle() is called — all pages update instantly.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeProvider,
      builder: (_, mode, __) {
        return MaterialApp.router(
          title: 'StudyMateAI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode, // the only thing that changes
          routerConfig: AppRoutes.router,
        );
      },
    );
  }
}

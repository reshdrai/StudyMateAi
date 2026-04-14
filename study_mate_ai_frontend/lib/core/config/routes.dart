import 'package:go_router/go_router.dart';

import '../../features/onboarding/landing_page.dart';
import '../../features/auth/auth_page.dart';
import '../../features/auth/forgot_password_page.dart';
import '../../features/home/home_page.dart';
import '../../features/upload/upload_page.dart';
import '../../features/goals/add_goal_page.dart';
import '../../features/notes/notes_library_page.dart';
import '../../features/progresss_analytics/progress_analytics_page.dart';

class AppRoutes {
  static const landing = '/';
  static const auth = '/auth';
  static const forgotPassword = '/forgot-password';

  static const home = '/home';
  static const upload = '/upload';
  static const addGoal = '/add-goal';
  static const library = '/library';
  static const analytics = '/analytics';

  static final router = GoRouter(
    initialLocation: landing,
    routes: [
      GoRoute(path: landing, builder: (_, __) => const LandingPage()),
      GoRoute(path: auth, builder: (_, __) => const AuthPage()),
      GoRoute(
        path: forgotPassword,
        builder: (_, __) => const ForgotPasswordPage(),
      ),

      GoRoute(path: home, builder: (_, __) => const HomePage()),
      GoRoute(path: upload, builder: (_, __) => const UploadPage()),
      GoRoute(path: addGoal, builder: (_, __) => const AddGoalPage()),
      GoRoute(path: library, builder: (_, __) => const NotesLibraryPage()),
      GoRoute(
        path: analytics,
        builder: (_, __) => const ProgressAnalyticsPage(),
      ),
    ],
  );
}

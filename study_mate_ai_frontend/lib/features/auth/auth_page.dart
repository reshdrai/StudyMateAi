import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/routes.dart';
import '../../core/theme/app_colors.dart';
import 'data/auth_repository.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _loading = false;

  final _loginEmail = TextEditingController();
  final _loginPassword = TextEditingController();

  final _signupName = TextEditingController();
  final _signupEmail = TextEditingController();
  final _signupPassword = TextEditingController();

  late final AuthRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = AuthRepository(); // ✅ no backend required now
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmail.dispose();
    _loginPassword.dispose();
    _signupName.dispose();
    _signupEmail.dispose();
    _signupPassword.dispose();
    super.dispose();
  }

  void _goToLogin() => _tabController.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );

  void _goToSignup() => _tabController.animateTo(
        1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );

  Future<void> _handleLogin() async {
    setState(() => _loading = true);
    try {
      await _repo.login(
        email: _loginEmail.text.trim(),
        password: _loginPassword.text,
      );

      if (!mounted) return;

      // ✅ GO to Home
      context.go(AppRoutes.home);

      // Optional feedback (might not show after navigation, that's ok)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Logged in (UI ready)")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleSignup() async {
    setState(() => _loading = true);
    try {
      await _repo.signup(
        fullName: _signupName.text.trim(),
        email: _signupEmail.text.trim(),
        password: _signupPassword.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account created (UI ready)")),
      );

      _goToLogin();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Signup failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _segmentedTabs() {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (_, __) {
        final index = _tabController.index;
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            children: [
              Expanded(
                child: _tabButton(
                  label: "Login",
                  active: index == 0,
                  onTap: _goToLogin,
                ),
              ),
              Expanded(
                child: _tabButton(
                  label: "Sign Up",
                  active: index == 1,
                  onTap: _goToSignup,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tabButton({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: active ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  // ✅ Common bottom section (kept same, but now scrolls safely)
  Widget _socialAndTerms() {
    return Column(
      children: [
        const SizedBox(height: 18),
        Row(
          children: const [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text("or", style: TextStyle(color: AppColors.textSecondary)),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 14),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              // ✅ WHEN GOOGLE AUTH IS READY:
              // Use firebase_auth + google_sign_in OR OAuth2 flow.
            },
            icon: const Icon(Icons.g_mobiledata),
            label: const Text("Google"),
          ),
        ),

        const SizedBox(height: 14),
        Text(
          "By continuing, you agree to our Terms of Service and Privacy Policy.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary.withOpacity(0.9), fontSize: 12),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text("Authentication"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        // ✅ This padding is the KEY FIX: adds space when keyboard opens
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, 10, 18, 18 + keyboard),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.auto_awesome, size: 30, color: AppColors.primary),
              ),
              const SizedBox(height: 14),

              // Smooth title/subtitle change
              AnimatedBuilder(
                animation: _tabController,
                builder: (_, __) {
                  final isLogin = _tabController.index == 0;
                  return Column(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Text(
                          isLogin ? "Study Smart" : "Create Account",
                          key: ValueKey(isLogin),
                          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Text(
                          isLogin
                              ? "Log in to access your AI-powered university assistant"
                              : "Sign up to start using StudyMateAI",
                          key: ValueKey("sub_$isLogin"),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 18),
              _segmentedTabs(),
              const SizedBox(height: 14),

              // ✅ IMPORTANT FIX: TabBarView must have bounded height => Expanded
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // ✅ Now each tab is fully scrollable (so no overflow)
                    ListView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.only(top: 6),
                      children: [
                        _LoginForm(
                          emailController: _loginEmail,
                          passwordController: _loginPassword,
                          loading: _loading,
                          onLogin: _handleLogin,
                          onForgotPassword: () => context.push(AppRoutes.forgotPassword),
                        ),
                        _socialAndTerms(),
                      ],
                    ),
                    ListView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.only(top: 6),
                      children: [
                        _SignupForm(
                          nameController: _signupName,
                          emailController: _signupEmail,
                          passwordController: _signupPassword,
                          loading: _loading,
                          onSignup: _handleSignup,
                        ),
                        _socialAndTerms(),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.emailController,
    required this.passwordController,
    required this.loading,
    required this.onLogin,
    required this.onForgotPassword,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool loading;
  final VoidCallback onLogin;
  final VoidCallback onForgotPassword;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "UNIVERSITY EMAIL",
            style: TextStyle(
              color: AppColors.textSecondary.withOpacity(0.9),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: "name@university.edu"),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "PASSWORD",
            style: TextStyle(
              color: AppColors.textSecondary.withOpacity(0.9),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(hintText: "Enter your password"),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onForgotPassword,
            child: const Text("Forgot password?"),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: loading ? null : onLogin,
            child: loading
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text("Sign In"),
          ),
        ),
      ],
    );
  }
}

class _SignupForm extends StatelessWidget {
  const _SignupForm({
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.loading,
    required this.onSignup,
  });

  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool loading;
  final VoidCallback onSignup;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "FULL NAME",
            style: TextStyle(
              color: AppColors.textSecondary.withOpacity(0.9),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: "Your name"),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "UNIVERSITY EMAIL",
            style: TextStyle(
              color: AppColors.textSecondary.withOpacity(0.9),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: "name@university.edu"),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "PASSWORD",
            style: TextStyle(
              color: AppColors.textSecondary.withOpacity(0.9),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(hintText: "Create a password"),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: loading ? null : onSignup,
            child: loading
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text("Create Account"),
          ),
        ),
      ],
    );
  }
}

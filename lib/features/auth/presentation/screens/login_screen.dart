import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/google_sign_in_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final result = await ref.read(authNotifierProvider.notifier).signInWithEmail(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    result.fold(
      (failure) => _showError(failure.message),
      (_) => context.go(AppRoutes.home),
    );
  }

  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);
    final result =
        await ref.read(authNotifierProvider.notifier).signInWithGoogle();
    if (!mounted) return;
    setState(() => _isLoading = false);

    result.fold(
      (failure) => _showError(failure.message),
      (_) => context.go(AppRoutes.home),
    );
  }

  Future<void> _forgotPassword() async {
    if (_emailCtrl.text.trim().isEmpty) {
      _showError('Enter your email address first');
      return;
    }
    await ref
        .read(authNotifierProvider.notifier)
        .sendPasswordReset(_emailCtrl.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent.')),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),

              // ── Logo ─────────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.prismPurple,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.change_history,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'The Prism',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.textPrimaryDark,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ).animate().fadeIn(duration: 500.ms),

              const SizedBox(height: 40),

              // ── Heading ───────────────────────────────────────────────
              Text(
                'Welcome back',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.textPrimaryDark,
                    ),
              ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.1, end: 0),

              const SizedBox(height: 6),

              Text(
                'Sign in to continue your analysis',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
              ).animate(delay: 150.ms).fadeIn(),

              const SizedBox(height: 36),

              // ── Form ──────────────────────────────────────────────────
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    AuthTextField(
                      controller: _emailCtrl,
                      label: 'Email address',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.email_outlined,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!v.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.05),

                    const SizedBox(height: 14),

                    AuthTextField(
                      controller: _passwordCtrl,
                      label: 'Password',
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _signIn(),
                      prefixIcon: Icons.lock_outlined,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.textTertiaryDark,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Password is required';
                        return null;
                      },
                    ).animate(delay: 250.ms).fadeIn().slideY(begin: 0.05),

                    const SizedBox(height: 10),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _forgotPassword,
                        child: const Text('Forgot password?'),
                      ),
                    ).animate(delay: 300.ms).fadeIn(),

                    const SizedBox(height: 16),

                    // Sign In button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signIn,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Sign in'),
                      ),
                    ).animate(delay: 350.ms).fadeIn(),

                    const SizedBox(height: 20),

                    // Divider
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'or',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.textTertiaryDark),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ).animate(delay: 400.ms).fadeIn(),

                    const SizedBox(height: 20),

                    // Google sign in
                    GoogleSignInButton(
                      onPressed: _isLoading ? null : _googleSignIn,
                    ).animate(delay: 450.ms).fadeIn(),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Sign up link
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Don't have an account?",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                    ),
                    TextButton(
                      onPressed: () => context.push(AppRoutes.signup),
                      child: const Text('Sign up'),
                    ),
                  ],
                ),
              ).animate(delay: 500.ms).fadeIn(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

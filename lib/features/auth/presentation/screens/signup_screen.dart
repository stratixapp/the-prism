import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/google_sign_in_button.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String _selectedIndustry = 'Technology';

  static const _industries = [
    'Technology', 'Business', 'Finance', 'Healthcare', 'Legal',
    'Research', 'Education', 'Marketing', 'Engineering', 'General',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final result = await ref.read(authNotifierProvider.notifier).signUpWithEmail(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          displayName: _nameCtrl.text.trim(),
          industry: _selectedIndustry.toLowerCase(),
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            backgroundColor: AppColors.error,
          ),
        );
      },
      (_) => context.go(AppRoutes.verifyEmail),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create account',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.textPrimaryDark,
                    ),
              ).animate().fadeIn().slideY(begin: 0.1),

              const SizedBox(height: 6),

              Text(
                'Join The Prism — powered by Stratix',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
              ).animate(delay: 80.ms).fadeIn(),

              // Free tier callout
              Container(
                margin: const EdgeInsets.only(top: 16, bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.prismPurpleDark.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.prismPurple.withOpacity(0.3), width: 0.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_outline,
                        color: AppColors.prismPurple, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Free tier: 3 analyses/month · 3 agents · No credit card',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.prismPurple,
                            ),
                      ),
                    ),
                  ],
                ),
              ).animate(delay: 120.ms).fadeIn(),

              const SizedBox(height: 24),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    AuthTextField(
                      controller: _nameCtrl,
                      label: 'Full name',
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.person_outline,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Name is required';
                        }
                        return null;
                      },
                    ).animate(delay: 160.ms).fadeIn(),

                    const SizedBox(height: 14),

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
                    ).animate(delay: 200.ms).fadeIn(),

                    const SizedBox(height: 14),

                    AuthTextField(
                      controller: _passwordCtrl,
                      label: 'Password',
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
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
                        if (v.length < 8) return 'Minimum 8 characters';
                        return null;
                      },
                    ).animate(delay: 240.ms).fadeIn(),

                    const SizedBox(height: 14),

                    // Industry picker
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your industry (agents will specialise)',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondaryDark,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _industries.map((industry) {
                            final isSelected = industry == _selectedIndustry;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedIndustry = industry),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.prismPurpleDark
                                      : AppColors.bgDarkCard,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.prismPurple
                                        : AppColors.borderDark,
                                    width: isSelected ? 1 : 0.5,
                                  ),
                                ),
                                child: Text(
                                  industry,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: isSelected
                                            ? AppColors.prismPurple
                                            : AppColors.textSecondaryDark,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ).animate(delay: 280.ms).fadeIn(),

                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signUp,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Create account'),
                      ),
                    ).animate(delay: 320.ms).fadeIn(),

                    const SizedBox(height: 20),

                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('or',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: AppColors.textTertiaryDark)),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ).animate(delay: 360.ms).fadeIn(),

                    const SizedBox(height: 20),

                    GoogleSignInButton(onPressed: _isLoading ? null : () async {
                      setState(() => _isLoading = true);
                      final result = await ref
                          .read(authNotifierProvider.notifier)
                          .signInWithGoogle();
                      if (!mounted) return;
                      setState(() => _isLoading = false);
                      result.fold(
                        (f) => ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(f.message),
                                backgroundColor: AppColors.error)),
                        (_) => context.go(AppRoutes.home),
                      );
                    }).animate(delay: 400.ms).fadeIn(),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Already have an account?',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                    ),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Sign in'),
                    ),
                  ],
                ),
              ).animate(delay: 440.ms).fadeIn(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

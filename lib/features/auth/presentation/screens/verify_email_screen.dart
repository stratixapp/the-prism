import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  Timer? _pollTimer;
  bool _canResend = true;
  int _resendCountdown = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      await FirebaseAuth.instance.currentUser?.reload();
      final user = FirebaseAuth.instance.currentUser;
      if (user?.emailVerified == true && mounted) {
        _pollTimer?.cancel();
        context.go(AppRoutes.home);
      }
    });
  }

  Future<void> _resendEmail() async {
    if (!_canResend) return;
    setState(() {
      _canResend = false;
      _resendCountdown = 60;
    });

    await ref
        .read(authNotifierProvider.notifier)
        .sendVerificationEmail();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _resendCountdown--);
      if (_resendCountdown <= 0) {
        t.cancel();
        setState(() => _canResend = true);
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification email sent!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final email =
        ref.watch(authStateProvider).valueOrNull?.email ?? 'your email';

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.prismPurpleDark.withOpacity(0.3),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.prismPurple.withOpacity(0.4), width: 1),
                ),
                child: const Icon(Icons.mark_email_unread_outlined,
                    color: AppColors.prismPurple, size: 36),
              ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),

              const SizedBox(height: 32),

              Text(
                'Check your inbox',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.textPrimaryDark,
                    ),
              ).animate(delay: 200.ms).fadeIn(),

              const SizedBox(height: 12),

              Text(
                'We sent a verification link to\n$email',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondaryDark,
                      height: 1.6,
                    ),
              ).animate(delay: 300.ms).fadeIn(),

              const SizedBox(height: 12),

              Text(
                'This screen will automatically advance once verified.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiaryDark,
                    ),
              ).animate(delay: 400.ms).fadeIn(),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canResend ? _resendEmail : null,
                  child: Text(
                    _canResend
                        ? 'Resend email'
                        : 'Resend in ${_resendCountdown}s',
                  ),
                ),
              ).animate(delay: 500.ms).fadeIn(),

              const SizedBox(height: 16),

              TextButton(
                onPressed: () async {
                  await ref
                      .read(authNotifierProvider.notifier)
                      .signOut();
                  if (mounted) context.go(AppRoutes.login);
                },
                child: Text(
                  'Use a different account',
                  style: TextStyle(color: AppColors.textTertiaryDark),
                ),
              ).animate(delay: 600.ms).fadeIn(),
            ],
          ),
        ),
      ),
    );
  }
}

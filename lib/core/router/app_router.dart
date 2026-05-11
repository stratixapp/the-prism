import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/analysis/presentation/screens/analysis_screen.dart';
import '../../features/results/presentation/screens/results_screen.dart';
import '../../features/history/presentation/screens/history_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

part 'app_router.g.dart';

// ── Route Names ──────────────────────────────────────────────────────────────
abstract class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const signup = '/signup';
  static const verifyEmail = '/verify-email';
  static const home = '/home';
  static const analysis = '/analysis/:analysisId';
  static const results = '/results/:analysisId';
  static const history = '/history';
  static const settings = '/settings';

  // Helpers
  static String analysisPath(String id) => '/analysis/$id';
  static String resultsPath(String id) => '/results/$id';
}

// ── Router Provider ──────────────────────────────────────────────────────────
@riverpod
GoRouter appRouter(AppRouterRef ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isOnAuthRoute = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.signup ||
          state.matchedLocation == AppRoutes.onboarding ||
          state.matchedLocation == AppRoutes.splash;

      // Loading state — stay on splash
      if (authState.isLoading) return AppRoutes.splash;

      // Not logged in and trying to access protected route
      if (!isLoggedIn && !isOnAuthRoute) return AppRoutes.login;

      // Logged in and on auth route — go home
      if (isLoggedIn && isOnAuthRoute &&
          state.matchedLocation != AppRoutes.splash) {
        return AppRoutes.home;
      }

      return null; // no redirect
    },
    routes: [
      // ── Splash ──────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // ── Onboarding ──────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const OnboardingScreen(),
          transitionsBuilder: _fadeTransition,
        ),
      ),

      // ── Auth ────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionsBuilder: _slideTransition,
        ),
      ),
      GoRoute(
        path: AppRoutes.signup,
        name: 'signup',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SignupScreen(),
          transitionsBuilder: _slideTransition,
        ),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        name: 'verifyEmail',
        builder: (context, state) => const VerifyEmailScreen(),
      ),

      // ── Main App Shell ───────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            name: 'home',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const HomeScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.history,
            name: 'history',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const HistoryScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.settings,
            name: 'settings',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const SettingsScreen(),
            ),
          ),
        ],
      ),

      // ── Full-screen routes (outside shell) ──────────────────────────
      GoRoute(
        path: AppRoutes.analysis,
        name: 'analysis',
        pageBuilder: (context, state) {
          final analysisId = state.pathParameters['analysisId']!;
          // Extra carries: { 'file': File, 'focusQuestion': String?, 'aiProvider': String? }
          final extra = state.extra as Map<String, dynamic>?;
          return CustomTransitionPage(
            key: state.pageKey,
            child: AnalysisScreen(
              analysisId: analysisId,
              file: extra?['file'] as File?,
              focusQuestion: extra?['focusQuestion'] as String?,
              aiProvider: extra?['aiProvider'] as String?,
            ),
            transitionsBuilder: _fadeTransition,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.results,
        name: 'results',
        pageBuilder: (context, state) {
          final analysisId = state.pathParameters['analysisId']!;
          return CustomTransitionPage(
            key: state.pageKey,
            child: ResultsScreen(analysisId: analysisId),
            transitionsBuilder: _slideTransition,
          );
        },
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFF0D0C1A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFE24B4A), size: 48),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: TextStyle(color: Colors.white.withOpacity(0.8)),
            ),
            const SizedBox(height: 8),
            Text(state.error.toString(),
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    ),
  );
}

// ── App Shell — Bottom Navigation ────────────────────────────────────────────
class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  static const _tabs = [
    AppRoutes.home,
    AppRoutes.history,
    AppRoutes.settings,
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _tabs.indexWhere((t) => location.startsWith(t));

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
        onDestinationSelected: (i) => context.go(_tabs[i]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// ── Transition Helpers ───────────────────────────────────────────────────────
Widget _fadeTransition(
    BuildContext context, Animation<double> animation,
    Animation<double> secondaryAnimation, Widget child) {
  return FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
    child: child,
  );
}

Widget _slideTransition(
    BuildContext context, Animation<double> animation,
    Animation<double> secondaryAnimation, Widget child) {
  return SlideTransition(
    position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
    child: FadeTransition(
      opacity: animation,
      child: child,
    ),
  );
}

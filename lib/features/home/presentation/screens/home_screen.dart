import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/agent_model.dart';
import '../../../../shared/models/analysis_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/home_provider.dart';
import '../widgets/upload_zone.dart';
import '../widgets/recent_analysis_card.dart';
import '../widgets/agent_spectrum_preview.dart';
import '../widgets/quota_banner.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── App Bar ─────────────────────────────────────────────────
            SliverAppBar(
              backgroundColor: AppColors.bgDark,
              floating: true,
              snap: true,
              title: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.prismPurple,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.change_history,
                        color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'The Prism',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.textPrimaryDark,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              actions: [
                userAsync.whenOrNull(
                  data: (user) => user != null && user.isFree
                      ? Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.prismPurpleDark.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.prismPurple.withOpacity(0.3)),
                          ),
                          child: Text(
                            '${user.remainingFreeAnalyses} left',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: AppColors.prismPurple),
                          ),
                        )
                      : null,
                ) ?? const SizedBox.shrink(),
              ],
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // ── Welcome greeting ────────────────────────────────
                    userAsync.when(
                      data: (user) => Text(
                        user != null
                            ? 'Hello, ${user.displayName.split(' ').first} 👋'
                            : 'Hello 👋',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(color: AppColors.textPrimaryDark),
                      ).animate().fadeIn(duration: 400.ms),
                      loading: () => const SizedBox(height: 28),
                      error: (_, __) => const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'Drop a file — the spectrum activates',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textTertiaryDark,
                          ),
                    ).animate(delay: 100.ms).fadeIn(),

                    const SizedBox(height: 24),

                    // ── Quota banner (free tier only) ──────────────────
                    userAsync.whenOrNull(
                      data: (user) =>
                          user != null && user.isFree && user.analysisCount > 0
                              ? QuotaBanner(user: user)
                                  .animate(delay: 150.ms)
                                  .fadeIn()
                              : null,
                    ) ?? const SizedBox.shrink(),

                    // ── Upload Zone ────────────────────────────────────
                    UploadZone(
                      onFileSelected: (file) {
                        ref
                            .read(homeNotifierProvider.notifier)
                            .startAnalysis(file, context);
                      },
                    ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.05),

                    const SizedBox(height: 28),

                    // ── Agent Spectrum Preview ─────────────────────────
                    Text(
                      '${AppConstants.agentCount} specialists · ${AppConstants.totalParameters} parameters',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textTertiaryDark,
                            letterSpacing: 0.3,
                          ),
                    ).animate(delay: 300.ms).fadeIn(),

                    const SizedBox(height: 10),

                    const AgentSpectrumPreview()
                        .animate(delay: 350.ms)
                        .fadeIn(),

                    const SizedBox(height: 32),

                    // ── Recent analyses ────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent analyses',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(color: AppColors.textPrimaryDark),
                        ),
                        TextButton(
                          onPressed: () => context.go(AppRoutes.history),
                          child: const Text('View all'),
                        ),
                      ],
                    ).animate(delay: 400.ms).fadeIn(),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // ── Recent analyses list ─────────────────────────────────────
            Consumer(
              builder: (context, ref, _) {
                final recentAsync = ref.watch(recentAnalysesProvider);
                return recentAsync.when(
                  data: (analyses) {
                    if (analyses.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 32),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.folder_open_outlined,
                                    color: AppColors.textTertiaryDark,
                                    size: 40),
                                const SizedBox(height: 12),
                                Text(
                                  'No analyses yet.\nUpload your first file above.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          color: AppColors.textTertiaryDark),
                                ),
                              ],
                            ),
                          ),
                        ).animate(delay: 450.ms).fadeIn(),
                      );
                    }

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 4),
                            child: RecentAnalysisCard(
                              analysis: analyses[i],
                              onTap: () => context.push(
                                  AppRoutes.resultsPath(analyses[i].id)),
                            ).animate(delay: (450 + i * 80).ms).fadeIn().slideY(
                                begin: 0.05, end: 0),
                          );
                        },
                        childCount: analyses.take(5).length,
                      ),
                    );
                  },
                  loading: () => SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: _shimmerList(),
                    ),
                  ),
                  error: (e, _) => SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('Could not load history',
                          style: TextStyle(color: AppColors.textTertiaryDark)),
                    ),
                  ),
                );
              },
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _shimmerList() {
    return Column(
      children: List.generate(
        3,
        (i) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.bgDarkCard,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

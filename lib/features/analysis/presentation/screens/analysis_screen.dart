// lib/features/analysis/presentation/screens/analysis_screen.dart
//
// THE HERO SCREEN OF THE PRISM.
// 10 agent cards streaming live in real time.

import 'dart:io';
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
import '../providers/analysis_provider.dart';
import '../widgets/agent_card_widget.dart';
import '../widgets/spectrum_progress_bar.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  final String analysisId;
  final File? file;
  final String? focusQuestion;
  final String? aiProvider;

  const AnalysisScreen({
    super.key,
    required this.analysisId,
    this.file,
    this.focusQuestion,
    this.aiProvider,
  });

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  bool _started = false;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_started && widget.file != null) {
        _started = true;
        _startAnalysis();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startAnalysis() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    final isPro = user?.isPro ?? false;
    final agentIds =
        isPro ? AppConstants.allAgentIds : AppConstants.freeAgentIds;

    await ref.read(analysisNotifierProvider.notifier).startAnalysis(
          file: widget.file!,
          focusQuestion: widget.focusQuestion ?? '',
          aiProvider:
              widget.aiProvider ?? AppConstants.aiProviderClaude,
          agentIds: agentIds,
          isPro: isPro,
        );
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(analysisNotifierProvider);

    // Auto-navigate to results on completion
    ref.listen(analysisNotifierProvider, (_, next) {
      final session = next.valueOrNull;
      if (session != null &&
          session.status == AnalysisStatus.complete &&
          !session.isCancelled &&
          mounted) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            context.pushReplacement(
                AppRoutes.resultsPath(session.analysisId));
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: sessionAsync.when(
        data: (session) => session == null
            ? _buildInitializing()
            : _buildSession(context, session),
        loading: () => _buildInitializing(),
        error: (e, _) => _buildError(context, e),
      ),
    );
  }

  Widget _buildInitializing() {
    return SafeArea(
      child: Column(
        children: [
          _AppBarRow(
            fileName: widget.file?.path.split('/').last ?? 'Analyzing...',
            onCancel: () => context.pop(),
          ),
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: AppColors.prismPurple,
                    strokeWidth: 2,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Uploading file...',
                    style: TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSession(
      BuildContext context, AnalysisSessionState session) {
    final agentIds = session.agentStates.keys.toList();

    final activeAgentId = agentIds.lastWhere(
      (id) {
        final s = session.agentStates[id];
        return s != null && s.isRunning && !s.isComplete;
      },
      orElse: () => '',
    );

    return SafeArea(
      child: Column(
        children: [
          _AppBarRow(
            fileName:
                widget.file?.path.split('/').last ?? 'Analysis',
            onCancel: session.isTerminal
                ? null
                : () => _showCancelDialog(context),
          ),

          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: SpectrumProgressBar(
              progress: session.progressFraction,
              statusLabel: _statusLabel(session.status),
              completedCount: session.completedAgentCount,
              totalCount: session.totalAgentCount,
            ),
          ).animate().fadeIn(duration: 400.ms),

          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: agentIds.length,
              itemBuilder: (context, i) {
                final agentId = agentIds[i];
                final streamState = session.agentStates[agentId]!;
                final agent = AgentRegistry.get(agentId);
                final isActive = agentId == activeAgentId;

                if (isActive && _scrollController.hasClients) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!_scrollController.hasClients) return;
                    final target = (i * 140.0).clamp(
                      0.0,
                      _scrollController.position.maxScrollExtent,
                    );
                    _scrollController.animateTo(
                      target,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                    );
                  });
                }

                return AgentCardWidget(
                  agent: agent,
                  streamState: streamState,
                  isActive: isActive,
                )
                    .animate(delay: (i * 60).ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.04, end: 0);
              },
            ),
          ),

          _BottomBar(session: session),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    final msg = error.toString().replaceAll('Exception: ', '');
    final isQuota = msg.contains('quota');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isQuota ? Icons.lock_outline : Icons.error_outline,
              color: isQuota ? AppColors.prismPurple : AppColors.error,
              size: 52,
            ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),

            const SizedBox(height: 22),

            Text(
              isQuota ? 'Free tier limit reached' : 'Analysis failed',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimaryDark,
                  ),
            ).animate(delay: 100.ms).fadeIn(),

            const SizedBox(height: 12),

            Text(
              isQuota
                  ? 'You\'ve used all 3 free analyses this month.\nUpgrade to Pro for unlimited access and all 10 agents.'
                  : msg,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryDark,
                    height: 1.65,
                  ),
            ).animate(delay: 160.ms).fadeIn(),

            const SizedBox(height: 36),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go back'),
                  ),
                ),
                if (isQuota) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => context.push(AppRoutes.settings),
                      child: const Text('Upgrade to Pro'),
                    ),
                  ),
                ],
              ],
            ).animate(delay: 220.ms).fadeIn(),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgDarkCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Stop analysis?'),
        content: const Text(
          'Agents will stop immediately. Completed outputs will be saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep going'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(analysisNotifierProvider.notifier).cancel();
              context.pop();
            },
            style: TextButton.styleFrom(
                foregroundColor: AppColors.error),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
  }

  String _statusLabel(AnalysisStatus status) {
    switch (status) {
      case AnalysisStatus.parsing:    return 'Parsing file...';
      case AnalysisStatus.running:    return 'Agents running...';
      case AnalysisStatus.synthesizing: return 'Chen synthesizing...';
      case AnalysisStatus.complete:   return 'Analysis complete ✓';
      case AnalysisStatus.failed:     return 'Analysis failed';
      default:                        return 'Starting...';
    }
  }
}

// ── App Bar Row ───────────────────────────────────────────────────────────────
class _AppBarRow extends StatelessWidget {
  final String fileName;
  final VoidCallback? onCancel;
  const _AppBarRow({required this.fileName, this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 0),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: AppColors.prismPurple,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.change_history,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('The Prism',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(
                          color: AppColors.prismPurple,
                          fontWeight: FontWeight.w600,
                        )),
                Text(fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color: AppColors.textTertiaryDark,
                          fontSize: 11,
                        )),
              ],
            ),
          ),
          if (onCancel != null)
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textTertiaryDark,
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
              ),
              child: const Text('Cancel',
                  style: TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }
}

// ── Bottom Bar ────────────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final AnalysisSessionState session;
  const _BottomBar({required this.session});

  @override
  Widget build(BuildContext context) {
    final tokensFormatted = session.totalTokens
        .toString()
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.bgDarkSurface,
        border: Border(
          top: BorderSide(color: AppColors.borderDark, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt_outlined,
              color: AppColors.textTertiaryDark, size: 13),
          const SizedBox(width: 3),
          Text(
            '$tokensFormatted tokens',
            style: const TextStyle(
              color: AppColors.textTertiaryDark,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 14),
          const Icon(Icons.attach_money,
              color: AppColors.textTertiaryDark, size: 13),
          Text(
            '\$${session.estimatedCostUsd.toStringAsFixed(3)}',
            style: const TextStyle(
              color: AppColors.textTertiaryDark,
              fontSize: 11,
            ),
          ),
          const Spacer(),
          if (session.status == AnalysisStatus.complete)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.success.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: AppColors.success, size: 12),
                  const SizedBox(width: 4),
                  const Text('Complete',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ),
            )
          else
            Text(
              '${session.completedAgentCount}/${session.totalAgentCount} done',
              style: const TextStyle(
                color: AppColors.textTertiaryDark,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }
}

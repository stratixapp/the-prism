// lib/features/analysis/presentation/widgets/analysis_launch_sheet.dart
//
// Bottom sheet shown after file selection.
// User can enter a focus question and choose AI provider before analysis starts.
// This is the "loading the scalpel" moment — everything gets configured here.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/agent_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class AnalysisLaunchSheet extends ConsumerStatefulWidget {
  final File file;

  const AnalysisLaunchSheet({super.key, required this.file});

  static Future<void> show(BuildContext context, File file) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AnalysisLaunchSheet(file: file),
    );
  }

  @override
  ConsumerState<AnalysisLaunchSheet> createState() =>
      _AnalysisLaunchSheetState();
}

class _AnalysisLaunchSheetState extends ConsumerState<AnalysisLaunchSheet> {
  final _questionCtrl = TextEditingController();
  String _selectedProvider = AppConstants.aiProviderClaude;
  bool _isLaunching = false;

  @override
  void dispose() {
    _questionCtrl.dispose();
    super.dispose();
  }

  String get _fileName => widget.file.path.split('/').last;
  String get _fileExt =>
      _fileName.contains('.') ? _fileName.split('.').last.toUpperCase() : 'FILE';

  int get _fileSizeKb {
    try {
      return (widget.file.lengthSync() / 1024).round();
    } catch (_) {
      return 0;
    }
  }

  Future<void> _launchAnalysis() async {
    if (_isLaunching) return;
    setState(() => _isLaunching = true);

    final userAsync = ref.read(currentUserProvider);
    final user = userAsync.valueOrNull;

    // Check quota
    if (user != null && !user.hasAnalysesRemaining) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'No free analyses left this month. Upgrade to Pro.'),
            backgroundColor: AppColors.error,
            action: SnackBarAction(
              label: 'Upgrade',
              textColor: Colors.white,
              onPressed: () => context.push(AppRoutes.settings),
            ),
          ),
        );
      }
      return;
    }

    // Generate analysis ID
    final analysisId =
        'analysis_${DateTime.now().millisecondsSinceEpoch}';

    if (mounted) {
      Navigator.pop(context);
      context.push(
        AppRoutes.analysisPath(analysisId),
        extra: {
          'file': widget.file,
          'focusQuestion': _questionCtrl.text.trim(),
          'aiProvider': _selectedProvider,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final isPro = userAsync.valueOrNull?.isPro ?? false;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgDarkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 32 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Handle ──────────────────────────────────────────────────
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderDark,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── File info ────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.prismPurpleDark.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.prismPurple.withOpacity(0.3)),
                ),
                child: Center(
                  child: Text(
                    _fileExt.length > 4 ? _fileExt.substring(0, 4) : _fileExt,
                    style: const TextStyle(
                      color: AppColors.prismPurple,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.textPrimaryDark,
                          ),
                    ),
                    Text(
                      '$_fileSizeKb KB · Ready for analysis',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiaryDark,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ).animate().fadeIn(duration: 300.ms),

          const SizedBox(height: 24),

          // ── Focus question ────────────────────────────────────────────
          Text(
            'Focus question',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _questionCtrl,
            maxLines: 2,
            textInputAction: TextInputAction.done,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimaryDark,
                ),
            decoration: InputDecoration(
              hintText:
                  'e.g. What are the biggest gaps? What is the future of this?',
              hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiaryDark,
                  ),
              hintMaxLines: 2,
            ),
          ).animate(delay: 80.ms).fadeIn(),

          const SizedBox(height: 20),

          // ── AI Provider selector ──────────────────────────────────────
          Text(
            'AI engine',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _ProviderChip(
                label: 'Claude',
                sublabel: 'Nuanced reasoning',
                value: AppConstants.aiProviderClaude,
                selected: _selectedProvider == AppConstants.aiProviderClaude,
                color: AppColors.prismPurple,
                onTap: () => setState(
                    () => _selectedProvider = AppConstants.aiProviderClaude),
              ),
              const SizedBox(width: 8),
              _ProviderChip(
                label: 'GPT-4o',
                sublabel: 'Broad knowledge',
                value: AppConstants.aiProviderOpenAI,
                selected: _selectedProvider == AppConstants.aiProviderOpenAI,
                color: AppColors.agentMarcus,
                onTap: () => setState(
                    () => _selectedProvider = AppConstants.aiProviderOpenAI),
                requiresPro: !isPro,
              ),
              const SizedBox(width: 8),
              _ProviderChip(
                label: 'Both',
                sublabel: 'Cross-validated',
                value: AppConstants.aiProviderBoth,
                selected: _selectedProvider == AppConstants.aiProviderBoth,
                color: AppColors.agentZara,
                onTap: () => setState(
                    () => _selectedProvider = AppConstants.aiProviderBoth),
                requiresPro: !isPro,
              ),
            ],
          ).animate(delay: 120.ms).fadeIn(),

          const SizedBox(height: 24),

          // ── Agent count info ─────────────────────────────────────────
          _AgentCountBanner(isPro: isPro)
              .animate(delay: 160.ms)
              .fadeIn(),

          const SizedBox(height: 20),

          // ── Launch button ─────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLaunching ? null : _launchAnalysis,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.prismPurple,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLaunching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.auto_awesome, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Activate the spectrum',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
            ),
          ).animate(delay: 200.ms).fadeIn(),
        ],
      ),
    );
  }
}

// ── Provider Chip ─────────────────────────────────────────────────────────────
class _ProviderChip extends StatelessWidget {
  final String label;
  final String sublabel;
  final String value;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final bool requiresPro;

  const _ProviderChip({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.selected,
    required this.color,
    required this.onTap,
    this.requiresPro = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: requiresPro ? null : onTap,
        child: AnimatedContainer(
          duration: AppConstants.animFast,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(
            color: selected
                ? color.withOpacity(0.12)
                : AppColors.bgDarkCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : AppColors.borderDark,
              width: selected ? 1 : 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: selected
                          ? color
                          : requiresPro
                              ? AppColors.textTertiaryDark
                              : AppColors.textPrimaryDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (requiresPro) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.prismPurpleDark,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PRO',
                        style: TextStyle(
                          color: AppColors.prismPurple,
                          fontSize: 7,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                sublabel,
                style: TextStyle(
                  color: AppColors.textTertiaryDark,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Agent Count Banner ────────────────────────────────────────────────────────
class _AgentCountBanner extends StatelessWidget {
  final bool isPro;

  const _AgentCountBanner({required this.isPro});

  @override
  Widget build(BuildContext context) {
    final agentCount = isPro
        ? AppConstants.proAgentsPerAnalysis
        : AppConstants.freeAgentsPerAnalysis;
    final agents = AgentRegistry.getForPlan(isPro);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgDarkCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderDark, width: 0.5),
      ),
      child: Row(
        children: [
          // Agent avatars strip
          SizedBox(
            width: agentCount * 18.0,
            height: 24,
            child: Stack(
              children: agents.take(agentCount).toList().asMap().entries.map((e) {
                final i = e.key;
                final agent = e.value;
                return Positioned(
                  left: i * 18.0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: agent.bgColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: agent.color.withOpacity(0.6), width: 1),
                    ),
                    child: Center(
                      child: Text(
                        agent.initials.substring(0, 1),
                        style: TextStyle(
                          color: agent.color,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isPro
                  ? 'All 10 agents activated · ${AppConstants.totalParameters} parameters'
                  : '$agentCount agents on free tier · Upgrade for all 10',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isPro
                        ? AppColors.textSecondaryDark
                        : AppColors.textTertiaryDark,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

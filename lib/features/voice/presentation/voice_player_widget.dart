// lib/features/voice/presentation/voice_player_widget.dart
// Phase 21 — Voice Player UI
//
// Mini player bar: shown at bottom of results screen when TTS is active.
// Full player sheet: expanded controls with agent list + speed selector.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/models/analysis_model.dart';
import '../../../shared/widgets/prism_widgets.dart';
import 'voice_service.dart';

// ── Mini Player Bar ───────────────────────────────────────────────────────────
class VoiceMiniPlayer extends ConsumerWidget {
  final AnalysisModel analysis;

  const VoiceMiniPlayer({super.key, required this.analysis});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceState = ref.watch(voiceNotifierProvider);
    final notifier = ref.read(voiceNotifierProvider.notifier);

    if (voiceState.isIdle) return const SizedBox.shrink();

    AgentModel? agent;
    if (voiceState.currentAgentId != null) {
      try {
        agent = AgentRegistry.get(voiceState.currentAgentId!);
      } catch (_) {}
    }

    return GestureDetector(
      onTap: () => _showFullPlayer(context, ref, analysis),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgDarkElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: agent?.color.withOpacity(0.3) ??
                AppColors.prismPurple.withOpacity(0.3),
          ),
          boxShadow: agent != null
              ? AppShadows.agentGlow(agent.color)
              : AppShadows.cardGlow,
        ),
        child: Row(
          children: [
            // Agent avatar
            if (agent != null)
              AgentAvatar(
                agent: agent,
                size: 28,
                isPulsing: voiceState.isPlaying,
              )
            else
              const Icon(Icons.record_voice_over,
                  color: AppColors.prismPurple, size: 24),

            const SizedBox(width: 10),

            // Agent name + status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    agent?.name ?? 'Reading...',
                    style: TextStyle(
                      color: agent?.color ?? AppColors.prismPurple,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    voiceState.isPlaying
                        ? 'Playing · ${voiceState.currentAgentIndex + 1}/${voiceState.queue.length}'
                        : voiceState.isComplete
                            ? 'Complete'
                            : 'Paused',
                    style: const TextStyle(
                      color: AppColors.textTertiaryDark,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),

            // Progress
            SizedBox(
              width: 48,
              child: SpectrumBar(
                progress: voiceState.overallProgress,
                height: 2,
              ),
            ),

            const SizedBox(width: 10),

            // Play/Pause
            GestureDetector(
              onTap: () => voiceState.isPlaying
                  ? notifier.pause()
                  : notifier.resume(),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: (agent?.color ?? AppColors.prismPurple)
                      .withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  voiceState.isPlaying
                      ? Icons.pause
                      : Icons.play_arrow,
                  color:
                      agent?.color ?? AppColors.prismPurple,
                  size: 18,
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Skip next
            GestureDetector(
              onTap: notifier.skipNext,
              child: const Icon(
                Icons.skip_next,
                color: AppColors.textTertiaryDark,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    ).animate().slideY(begin: 1, end: 0, duration: 300.ms);
  }

  void _showFullPlayer(
    BuildContext context,
    WidgetRef ref,
    AnalysisModel analysis,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FullPlayerSheet(
          analysis: analysis),
    );
  }
}

// ── Full Player Sheet ─────────────────────────────────────────────────────────
class _FullPlayerSheet extends ConsumerWidget {
  final AnalysisModel analysis;

  const _FullPlayerSheet({required this.analysis});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceState = ref.watch(voiceNotifierProvider);
    final notifier = ref.read(voiceNotifierProvider.notifier);

    AgentModel? currentAgent;
    if (voiceState.currentAgentId != null) {
      try {
        currentAgent = AgentRegistry.get(voiceState.currentAgentId!);
      } catch (_) {}
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.bgDarkSurface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderDark,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Current agent display
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (currentAgent != null)
                    AgentAvatar(
                      agent: currentAgent,
                      size: 64,
                      isPulsing: voiceState.isPlaying,
                    ),
                  const SizedBox(height: 12),
                  Text(
                    currentAgent?.name ?? 'The Prism',
                    style: AppTextStyles.h2.copyWith(
                        color: currentAgent?.color ??
                            AppColors.prismPurple),
                  ),
                  Text(
                    currentAgent?.role ?? 'Voice Readout',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),

            // Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SpectrumBar(
                progress: voiceState.overallProgress,
                height: 4,
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Agent ${voiceState.currentAgentIndex + 1}',
                    style: AppTextStyles.labelSmall,
                  ),
                  Text(
                    'of ${voiceState.queue.length}',
                    style: AppTextStyles.labelSmall,
                  ),
                ],
              ),
            ),

            // Controls
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Skip previous
                  _ControlButton(
                    icon: Icons.skip_previous,
                    onTap: notifier.skipPrevious,
                    size: 36,
                  ),

                  // Play / Pause
                  GestureDetector(
                    onTap: voiceState.isPlaying
                        ? notifier.pause
                        : notifier.resume,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: currentAgent?.color ??
                            AppColors.prismPurple,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        voiceState.isPlaying
                            ? Icons.pause
                            : Icons.play_arrow,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),

                  // Skip next
                  _ControlButton(
                    icon: Icons.skip_next,
                    onTap: notifier.skipNext,
                    size: 36,
                  ),

                  // Speed
                  GestureDetector(
                    onTap: notifier.cycleSpeed,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.bgDarkCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.borderDark, width: 0.5),
                      ),
                      child: Text(
                        '${voiceState.speed}x',
                        style: const TextStyle(
                          color: AppColors.textPrimaryDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  // Stop
                  _ControlButton(
                    icon: Icons.stop,
                    onTap: () {
                      notifier.stop();
                      Navigator.pop(context);
                    },
                    size: 36,
                    color: AppColors.error,
                  ),
                ],
              ),
            ),

            const PrismDivider(),

            // Agent queue list
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(16),
                itemCount: voiceState.queue.length,
                itemBuilder: (_, i) {
                  final output = voiceState.queue[i];
                  final isActive =
                      i == voiceState.currentAgentIndex;
                  AgentModel? agent;
                  try {
                    agent = AgentRegistry.get(output.agentId);
                  } catch (_) {}

                  return GestureDetector(
                    onTap: () => notifier.startFromAgent(
                        analysis, output.agentId),
                    child: AnimatedContainer(
                      duration: AppConstants.animFast,
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isActive
                            ? (agent?.color ?? AppColors.prismPurple)
                                .withOpacity(0.1)
                            : AppColors.bgDarkCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isActive
                              ? (agent?.color ??
                                      AppColors.prismPurple)
                                  .withOpacity(0.4)
                              : AppColors.borderDark,
                          width: 0.5,
                        ),
                      ),
                      child: Row(children: [
                        if (agent != null)
                          AgentAvatar(
                            agent: agent,
                            size: 28,
                            isPulsing:
                                isActive && voiceState.isPlaying,
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            agent?.name ?? output.agentId,
                            style: TextStyle(
                              color: isActive
                                  ? agent?.color ??
                                      AppColors.prismPurple
                                  : AppColors.textPrimaryDark,
                              fontSize: 13,
                              fontWeight: isActive
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (i < voiceState.currentAgentIndex)
                          const Icon(Icons.check,
                              color: AppColors.success, size: 16)
                        else if (isActive)
                          Icon(
                              voiceState.isPlaying
                                  ? Icons.graphic_eq
                                  : Icons.pause,
                              color: agent?.color ??
                                  AppColors.prismPurple,
                              size: 16),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color? color;

  const _ControlButton({
    required this.icon,
    required this.onTap,
    required this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.bgDarkCard,
          shape: BoxShape.circle,
          border:
              Border.all(color: AppColors.borderDark, width: 0.5),
        ),
        child: Icon(
          icon,
          color: color ?? AppColors.textSecondaryDark,
          size: size * 0.5,
        ),
      ),
    );
  }
}

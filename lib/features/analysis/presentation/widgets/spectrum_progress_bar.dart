// lib/features/analysis/presentation/widgets/spectrum_progress_bar.dart
//
// The spectrum progress bar at the top of the analysis screen.
// Fills left to right as agents complete, using the full
// prismatic color spectrum gradient.

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class SpectrumProgressBar extends StatelessWidget {
  final double progress;       // 0.0 to 1.0
  final String statusLabel;
  final int completedCount;
  final int totalCount;

  const SpectrumProgressBar({
    super.key,
    required this.progress,
    required this.statusLabel,
    required this.completedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Label row ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                statusLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondaryDark,
                      letterSpacing: 0.3,
                    ),
              ),
              Text(
                '$completedCount / $totalCount agents',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textTertiaryDark,
                    ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // ── Bar ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  // Track
                  Container(
                    height: 4,
                    width: constraints.maxWidth,
                    decoration: BoxDecoration(
                      color: AppColors.borderDark,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Spectrum fill
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    height: 4,
                    width: constraints.maxWidth * progress.clamp(0.0, 1.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: const LinearGradient(
                        colors: AppColors.spectrumGradient,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.prismPurple.withOpacity(0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Segment progress bar (one dot per agent, fills as each completes) ─────────
class AgentSegmentBar extends StatelessWidget {
  final List<_AgentSegment> segments;

  const AgentSegmentBar({super.key, required this.segments});

  factory AgentSegmentBar.fromStates({
    required List<String> agentIds,
    required Map<String, dynamic> agentStates,
  }) {
    return AgentSegmentBar(
      segments: agentIds.map((id) {
        final state = agentStates[id];
        return _AgentSegment(
          agentId: id,
          isComplete: state?.isComplete ?? false,
          isRunning: state?.isRunning ?? false,
          hasError: state?.hasError ?? false,
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: segments.asMap().entries.map((entry) {
          final i = entry.key;
          final seg = entry.value;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < segments.length - 1 ? 2 : 0),
              child: _SegmentDot(segment: seg),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AgentSegment {
  final String agentId;
  final bool isComplete;
  final bool isRunning;
  final bool hasError;
  const _AgentSegment({
    required this.agentId,
    required this.isComplete,
    required this.isRunning,
    required this.hasError,
  });
}

class _SegmentDot extends StatelessWidget {
  final _AgentSegment segment;
  const _SegmentDot({required this.segment});

  @override
  Widget build(BuildContext context) {
    Color color;
    if (segment.hasError) {
      color = AppColors.error;
    } else if (segment.isComplete) {
      color = AppColors.success;
    } else if (segment.isRunning) {
      color = AppColors.prismPurple;
    } else {
      color = AppColors.borderDark;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      height: 3,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}

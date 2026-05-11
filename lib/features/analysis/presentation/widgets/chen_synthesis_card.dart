// lib/features/analysis/presentation/widgets/chen_synthesis_card.dart
//
// Chen's synthesis card — visually distinct from all other agent cards.
// Appears at the bottom AFTER all 9 specialists complete.
// Shows:
//   • Deep purple glow + border (Chen's signature colour)
//   • "Master Synthesizer" label
//   • Three structured sections: #1 Insight, #1 Gap, #1 Opportunity
//   • Parsing logic to split Chen's structured output into sections
//   • Confidence score pill if present

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/agent_model.dart';
import '../providers/analysis_provider.dart';

class ChenSynthesisCard extends StatelessWidget {
  final AgentModel agent;
  final AgentStreamState streamState;
  final bool isActive;

  const ChenSynthesisCard({
    super.key,
    required this.agent,
    required this.streamState,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      decoration: BoxDecoration(
        color: AppColors.agentChenBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? AppColors.agentChen.withOpacity(0.7)
              : streamState.isComplete
                  ? AppColors.agentChen.withOpacity(0.4)
                  : AppColors.borderDark,
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: (isActive || streamState.isComplete)
            ? [
                BoxShadow(
                  color: AppColors.agentChen.withOpacity(
                      isActive ? 0.3 : 0.15),
                  blurRadius: isActive ? 24 : 12,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────
          _ChenHeader(agent: agent, streamState: streamState, isActive: isActive),

          // ── Content ───────────────────────────────────────────────────
          if (streamState.accumulatedText.isNotEmpty ||
              streamState.isRunning ||
              streamState.hasError)
            _ChenContent(streamState: streamState, isActive: isActive),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _ChenHeader extends StatelessWidget {
  final AgentModel agent;
  final AgentStreamState streamState;
  final bool isActive;

  const _ChenHeader({
    required this.agent,
    required this.streamState,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Row(
        children: [
          // Avatar with glow
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.agentChen.withOpacity(isActive ? 0.3 : 0.15),
              border: Border.all(
                color: AppColors.agentChen.withOpacity(isActive ? 0.8 : 0.4),
                width: isActive ? 1.5 : 1,
              ),
            ),
            child: Center(
              child: Text(
                agent.initials,
                style: const TextStyle(
                  color: AppColors.agentChen,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          )
              .animate(target: isActive ? 1 : 0)
              .custom(
                duration: 1400.ms,
                curve: Curves.easeInOut,
                builder: (_, v, child) =>
                    Transform.scale(scale: 1.0 + 0.05 * v, child: child),
              )
              .then()
              .custom(
                duration: 1400.ms,
                curve: Curves.easeInOut,
                builder: (_, v, child) =>
                    Transform.scale(scale: 1.05 - 0.05 * v, child: child),
              ),

          const SizedBox(width: 10),

          // Name + role
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      agent.name,
                      style: const TextStyle(
                        color: AppColors.agentChen,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.agentChen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppColors.agentChen.withOpacity(0.3),
                          width: 0.5,
                        ),
                      ),
                      child: const Text(
                        'SYNTHESIS',
                        style: TextStyle(
                          color: AppColors.agentChen,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  agent.role,
                  style: TextStyle(
                    color: AppColors.agentChen.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Status
          _ChenStatus(streamState: streamState, isActive: isActive),
        ],
      ),
    );
  }
}

// ── Status pill ───────────────────────────────────────────────────────────────
class _ChenStatus extends StatelessWidget {
  final AgentStreamState streamState;
  final bool isActive;

  const _ChenStatus({required this.streamState, required this.isActive});

  @override
  Widget build(BuildContext context) {
    if (streamState.hasError) {
      return const Icon(Icons.error_outline,
          color: AppColors.error, size: 18);
    }
    if (streamState.isComplete) {
      return const Icon(Icons.auto_awesome,
              color: AppColors.agentChen, size: 20)
          .animate()
          .scale(duration: 400.ms, curve: Curves.elasticOut);
    }
    if (isActive || streamState.isRunning) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: AppColors.agentChen,
        ),
      );
    }
    // Waiting
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.agentChen.withOpacity(0.25),
      ),
    );
  }
}

// ── Content ───────────────────────────────────────────────────────────────────
class _ChenContent extends StatelessWidget {
  final AgentStreamState streamState;
  final bool isActive;

  const _ChenContent({required this.streamState, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, thickness: 0.5,
              color: AppColors.borderDark),
          const SizedBox(height: 12),

          if (streamState.hasError)
            Text(
              streamState.errorMessage ?? 'Chen encountered an error',
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            )
          else if (streamState.isComplete && streamState.accumulatedText.isNotEmpty)
            _ChenParsedOutput(text: streamState.accumulatedText)
          else
            _ChenStreamingRaw(
              text: streamState.accumulatedText,
              isActive: isActive,
            ),
        ],
      ),
    );
  }
}

// ── Streaming raw text (while still writing) ──────────────────────────────────
class _ChenStreamingRaw extends StatefulWidget {
  final String text;
  final bool isActive;

  const _ChenStreamingRaw({required this.text, required this.isActive});

  @override
  State<_ChenStreamingRaw> createState() => _ChenStreamingRawState();
}

class _ChenStreamingRawState extends State<_ChenStreamingRaw>
    with SingleTickerProviderStateMixin {
  late AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) {
      return Row(
        children: [
          const Text(
            'Synthesizing all outputs',
            style: TextStyle(
              color: AppColors.agentChen,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 4),
          AnimatedBuilder(
            animation: _dotController,
            builder: (_, __) => Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final delay = i / 3;
                final t = ((_dotController.value - delay) % 1.0).clamp(0.0, 1.0);
                final opacity = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.2, 1.0);
                return Opacity(
                  opacity: opacity,
                  child: const Text(
                    '.',
                    style: TextStyle(
                      color: AppColors.agentChen,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      );
    }

    // Show streaming text with cursor
    final displayText = widget.text.length > 1200
        ? '...${widget.text.substring(widget.text.length - 1200)}'
        : widget.text;

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: displayText,
            style: const TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 12.5,
              height: 1.65,
              fontFamily: 'Inter',
            ),
          ),
          if (widget.isActive)
            WidgetSpan(
              child: Container(
                width: 2,
                height: 13,
                margin: const EdgeInsets.only(left: 1),
                color: AppColors.agentChen,
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .fadeIn(duration: 500.ms)
                  .fadeOut(duration: 500.ms),
            ),
        ],
      ),
    );
  }
}

// ── Parsed output — structured into 3 sections ───────────────────────────────
class _ChenParsedOutput extends StatelessWidget {
  final String text;
  const _ChenParsedOutput({required this.text});

  @override
  Widget build(BuildContext context) {
    final sections = _parseChenOutput(text);

    // If we couldn't parse sections cleanly, show raw text
    if (sections.isEmpty) {
      return Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondaryDark,
          fontSize: 12.5,
          height: 1.65,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections.asMap().entries.map((entry) {
        final i = entry.key;
        final section = entry.value;
        return _ChenSection(
          section: section,
          animationDelay: Duration(milliseconds: 150 * i),
        );
      }).toList(),
    );
  }

  List<_ChenSection_Data> _parseChenOutput(String text) {
    final sections = <_ChenSection_Data>[];

    // Pattern: **#1 INSIGHT** or **#1 GAP** or **#1 OPPORTUNITY**
    final sectionDefs = [
      _SectionDef(
        patterns: ['#1 INSIGHT', '#1 Insight', 'INSIGHT'],
        label: '#1 INSIGHT',
        icon: Icons.lightbulb_outline,
        color: AppColors.agentPriya,
      ),
      _SectionDef(
        patterns: ['#1 GAP', '#1 Gap', 'GAP'],
        label: '#1 GAP',
        icon: Icons.search_off_outlined,
        color: AppColors.agentMarcus,
      ),
      _SectionDef(
        patterns: ['#1 OPPORTUNITY', '#1 Opportunity', 'OPPORTUNITY'],
        label: '#1 OPPORTUNITY',
        icon: Icons.rocket_launch_outlined,
        color: AppColors.agentZara,
      ),
    ];

    for (int i = 0; i < sectionDefs.length; i++) {
      final def = sectionDefs[i];
      String? sectionText;

      for (final pattern in def.patterns) {
        // Find section start
        final startIdx = text.indexOf(pattern);
        if (startIdx == -1) continue;

        // Find section end (next ** header or end of string)
        int endIdx = text.length;
        for (int j = i + 1; j < sectionDefs.length; j++) {
          for (final nextPattern in sectionDefs[j].patterns) {
            final nextIdx = text.indexOf(nextPattern, startIdx + 1);
            if (nextIdx != -1 && nextIdx < endIdx) {
              endIdx = nextIdx;
            }
          }
        }

        // Extract and clean content
        final raw = text.substring(startIdx + pattern.length, endIdx);
        sectionText = raw
            .replaceAll(RegExp(r'\*+'), '')  // remove markdown bold
            .replaceAll(RegExp(r'#{1,3}\s*'), '') // remove headers
            .replaceAll(RegExp(r'\n{3,}'), '\n\n')
            .trim();
        break;
      }

      if (sectionText != null && sectionText.isNotEmpty) {
        sections.add(_ChenSection_Data(
          label: def.label,
          content: sectionText,
          icon: def.icon,
          color: def.color,
        ));
      }
    }

    return sections;
  }
}

class _SectionDef {
  final List<String> patterns;
  final String label;
  final IconData icon;
  final Color color;
  const _SectionDef({
    required this.patterns,
    required this.label,
    required this.icon,
    required this.color,
  });
}

class _ChenSection_Data {
  final String label;
  final String content;
  final IconData icon;
  final Color color;
  const _ChenSection_Data({
    required this.label,
    required this.content,
    required this.icon,
    required this.color,
  });
}

class _ChenSection extends StatelessWidget {
  final _ChenSection_Data section;
  final Duration animationDelay;

  const _ChenSection({
    required this.section,
    required this.animationDelay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: section.color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: section.color.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(section.icon, color: section.color, size: 14),
              const SizedBox(width: 6),
              Text(
                section.label,
                style: TextStyle(
                  color: section.color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            section.content,
            style: const TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 12.5,
              height: 1.65,
            ),
          ),
        ],
      ),
    )
        .animate(delay: animationDelay)
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.05, end: 0);
  }
}

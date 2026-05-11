// lib/features/analysis/presentation/widgets/agent_card_widget.dart
//
// The individual agent card shown on the live analysis screen.
// Shows:
//   • Agent avatar + name + role
//   • Live streaming text with typing cursor
//   • State: dormant → running (glow pulse) → complete (checkmark)
//   • Word count + duration on completion
//   • Error state with red border

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/agent_model.dart';
import '../providers/analysis_provider.dart';

class AgentCardWidget extends StatelessWidget {
  final AgentModel agent;
  final AgentStreamState streamState;
  final bool isActive; // currently streaming

  const AgentCardWidget({
    super.key,
    required this.agent,
    required this.streamState,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(
        color: agent.bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _borderColor(),
          width: _borderWidth(),
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: agent.color.withOpacity(0.25),
                  blurRadius: 16,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ───────────────────────────────────────────
            Row(
              children: [
                // Avatar
                _AgentAvatar(agent: agent, isActive: isActive),
                const SizedBox(width: 10),

                // Name + role
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        agent.name,
                        style: TextStyle(
                          color: agent.color,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                      Text(
                        agent.role,
                        style: TextStyle(
                          color: agent.color.withOpacity(0.6),
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),

                // Status indicator
                _StatusIndicator(
                  agent: agent,
                  streamState: streamState,
                  isActive: isActive,
                ),
              ],
            ),

            // ── Content area ──────────────────────────────────────────
            if (streamState.accumulatedText.isNotEmpty ||
                streamState.isRunning ||
                streamState.hasError) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, thickness: 0.5),
              const SizedBox(height: 10),
              _ContentArea(
                agent: agent,
                streamState: streamState,
                isActive: isActive,
              ),
            ],

            // ── Footer: word count + duration ─────────────────────────
            if (streamState.isComplete && !streamState.hasError) ...[
              const SizedBox(height: 8),
              _Footer(agent: agent, streamState: streamState),
            ],
          ],
        ),
      ),
    );
  }

  Color _borderColor() {
    if (streamState.hasError) return AppColors.error.withOpacity(0.5);
    if (isActive) return agent.color.withOpacity(0.6);
    if (streamState.isComplete) return agent.color.withOpacity(0.25);
    return AppColors.borderDark;
  }

  double _borderWidth() {
    if (isActive) return 1.5;
    if (streamState.isComplete) return 0.8;
    return 0.5;
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────
class _AgentAvatar extends StatelessWidget {
  final AgentModel agent;
  final bool isActive;

  const _AgentAvatar({required this.agent, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: agent.color.withOpacity(isActive ? 0.25 : 0.12),
        border: Border.all(
          color: agent.color.withOpacity(isActive ? 0.7 : 0.3),
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Center(
        child: Text(
          agent.initials,
          style: TextStyle(
            color: agent.color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    )
        .animate(target: isActive ? 1 : 0)
        .custom(
          duration: 1200.ms,
          curve: Curves.easeInOut,
          builder: (context, value, child) {
            // Subtle pulse when active
            return Transform.scale(
              scale: 1.0 + (0.04 * value),
              child: child,
            );
          },
        )
        .then()
        .custom(
          duration: 1200.ms,
          curve: Curves.easeInOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: 1.04 - (0.04 * value),
              child: child,
            );
          },
        );
  }
}

// ── Status Indicator ──────────────────────────────────────────────────────────
class _StatusIndicator extends StatelessWidget {
  final AgentModel agent;
  final AgentStreamState streamState;
  final bool isActive;

  const _StatusIndicator({
    required this.agent,
    required this.streamState,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    if (streamState.hasError) {
      return Icon(Icons.error_outline,
          color: AppColors.error, size: 18);
    }

    if (streamState.isComplete) {
      return Icon(Icons.check_circle_outline,
          color: agent.color, size: 18)
          .animate()
          .scale(duration: 300.ms, curve: Curves.elasticOut);
    }

    if (isActive || streamState.isRunning) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: agent.color,
        ),
      );
    }

    // Dormant
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.textTertiaryDark.withOpacity(0.4),
      ),
    );
  }
}

// ── Content Area ──────────────────────────────────────────────────────────────
class _ContentArea extends StatelessWidget {
  final AgentModel agent;
  final AgentStreamState streamState;
  final bool isActive;

  const _ContentArea({
    required this.agent,
    required this.streamState,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    if (streamState.hasError) {
      return Text(
        streamState.errorMessage ?? 'Agent encountered an error',
        style: TextStyle(
          color: AppColors.error.withOpacity(0.8),
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final text = streamState.accumulatedText;
    if (text.isEmpty) {
      return _ThinkingIndicator(color: agent.color);
    }

    return _StreamingText(
      text: text,
      color: AppColors.textSecondaryDark,
      showCursor: isActive && !streamState.isComplete,
      cursorColor: agent.color,
    );
  }
}

// ── Thinking indicator (before first token) ───────────────────────────────────
class _ThinkingIndicator extends StatefulWidget {
  final Color color;
  const _ThinkingIndicator({required this.color});

  @override
  State<_ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Thinking',
          style: TextStyle(
            color: widget.color.withOpacity(0.5),
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(width: 4),
        AnimatedBuilder(
          animation: _controller,
          builder: (_, __) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final delay = i / 3;
              final t = ((_controller.value - delay) % 1.0).clamp(0.0, 1.0);
              final opacity =
                  (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.2, 1.0);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Opacity(
                  opacity: opacity,
                  child: Text(
                    '.',
                    style: TextStyle(
                      color: widget.color,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

// ── Streaming Text ─────────────────────────────────────────────────────────────
class _StreamingText extends StatelessWidget {
  final String text;
  final Color color;
  final bool showCursor;
  final Color cursorColor;

  const _StreamingText({
    required this.text,
    required this.color,
    required this.showCursor,
    required this.cursorColor,
  });

  @override
  Widget build(BuildContext context) {
    // Show only last ~800 chars for performance during streaming
    final displayText = text.length > 800
        ? '...${text.substring(text.length - 800)}'
        : text;

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: displayText,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              height: 1.65,
              fontFamily: 'Inter',
            ),
          ),
          if (showCursor)
            WidgetSpan(
              child: _BlinkingCursor(color: cursorColor),
            ),
        ],
      ),
    );
  }
}

// ── Blinking Cursor ───────────────────────────────────────────────────────────
class _BlinkingCursor extends StatelessWidget {
  final Color color;
  const _BlinkingCursor({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      height: 13,
      margin: const EdgeInsets.only(left: 1),
      color: color,
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fadeIn(duration: 500.ms)
        .fadeOut(duration: 500.ms);
  }
}

// ── Footer: word count + timing ───────────────────────────────────────────────
class _Footer extends StatelessWidget {
  final AgentModel agent;
  final AgentStreamState streamState;

  const _Footer({required this.agent, required this.streamState});

  @override
  Widget build(BuildContext context) {
    final wordCount = streamState.accumulatedText
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    final seconds = (streamState.durationMs / 1000).toStringAsFixed(1);

    return Row(
      children: [
        Icon(Icons.article_outlined,
            color: agent.color.withOpacity(0.4), size: 11),
        const SizedBox(width: 4),
        Text(
          '$wordCount words',
          style: TextStyle(
            color: agent.color.withOpacity(0.5),
            fontSize: 10,
          ),
        ),
        const SizedBox(width: 12),
        Icon(Icons.timer_outlined,
            color: agent.color.withOpacity(0.4), size: 11),
        const SizedBox(width: 4),
        Text(
          '${seconds}s',
          style: TextStyle(
            color: agent.color.withOpacity(0.5),
            fontSize: 10,
          ),
        ),
        if (streamState.tokensUsed > 0) ...[
          const SizedBox(width: 12),
          Text(
            '${streamState.tokensUsed} tokens',
            style: TextStyle(
              color: agent.color.withOpacity(0.4),
              fontSize: 10,
            ),
          ),
        ],
      ],
    );
  }
}

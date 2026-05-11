// lib/features/debate/presentation/screens/debate_screen.dart
// Phase 18 — Agent Debate Mode (Pro feature)
//
// Split screen: Agent A on left, Agent B on right.
// User picks topic → both agents stream simultaneously.
// Structured: Opening → 3 Arguments → Rebuttal → Closing.
// User votes winner at the end.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/models/agent_model.dart';
import '../../../../shared/models/analysis_model.dart';
import '../../../../shared/widgets/prism_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/debate_service.dart';

// ── Debate State Provider ─────────────────────────────────────────────────────
final _debateStateProvider =
    StateProvider<DebateState?>((ref) => null);

final _debateServiceProvider =
    Provider<DebateService>((ref) {
  final service = DebateService();
  ref.onDispose(service.dispose);
  return service;
});

// ── Screen ────────────────────────────────────────────────────────────────────
class DebateScreen extends ConsumerStatefulWidget {
  final AnalysisModel analysis;
  final String agentAId;
  final String agentBId;
  final String topic;

  const DebateScreen({
    super.key,
    required this.analysis,
    required this.agentAId,
    required this.agentBId,
    required this.topic,
  });

  @override
  ConsumerState<DebateScreen> createState() =>
      _DebateScreenState();
}

class _DebateScreenState extends ConsumerState<DebateScreen> {
  // Streaming text per agent per stage
  final Map<String, Map<DebateStage, String>> _texts = {};
  DebateStage _currentStage = DebateStage.opening;
  bool _isRunning = false;
  bool _isComplete = false;
  String? _userVote;
  StreamSubscription? _sub;

  AgentModel get _agentA => AgentRegistry.get(widget.agentAId);
  AgentModel get _agentB => AgentRegistry.get(widget.agentBId);

  @override
  void initState() {
    super.initState();
    _initTexts();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _startDebate());
  }

  void _initTexts() {
    for (final id in [widget.agentAId, widget.agentBId]) {
      _texts[id] = {
        for (final s in DebateStage.values) s: '',
      };
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _startDebate() async {
    if (_isRunning) return;
    setState(() => _isRunning = true);

    final service = ref.read(_debateServiceProvider);
    final stream = service.startDebate(
      agentAId: widget.agentAId,
      agentBId: widget.agentBId,
      topic: widget.topic,
      fileContext: widget.analysis.synthesis?.fullText ??
          widget.analysis.focusQuestion ??
          widget.analysis.fileMetadata.name,
      analysis: widget.analysis,
    );

    _sub = stream.listen(
      (event) {
        if (!mounted) return;
        setState(() {
          switch (event.type) {
            case 'stage_start':
              if (event.stage != null) {
                _currentStage = event.stage!;
              }
              break;

            case 'token':
              if (event.agentId != null &&
                  event.token != null &&
                  _texts.containsKey(event.agentId)) {
                _texts[event.agentId]![_currentStage] =
                    (_texts[event.agentId]![_currentStage] ?? '') +
                        event.token!;
              }
              break;

            case 'debate_complete':
              _isComplete = true;
              _isRunning = false;
              break;
          }
        });
      },
      onError: (_) {
        if (mounted) setState(() => _isRunning = false);
      },
      onDone: () {
        if (mounted) setState(() {
          _isComplete = true;
          _isRunning = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final isPro = userAsync.valueOrNull?.isPro ?? false;

    if (!isPro) {
      return Scaffold(
        backgroundColor: AppColors.bgDark,
        appBar: AppBar(title: const Text('Debate Mode')),
        body: EmptyState(
          icon: Icons.lock_outline,
          title: 'Pro Feature',
          subtitle:
              'Agent Debate Mode is available on The Prism Pro.',
          actionLabel: 'Upgrade',
          onAction: () => context.pop(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        leading: IconButton(
          icon: const Icon(Icons.close, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Agent Debate', style: TextStyle(fontSize: 16)),
            Text(
              widget.topic,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiaryDark),
            ),
          ],
        ),
        actions: [
          if (_isRunning)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.warning,
                    shape: BoxShape.circle,
                  ),
                )
                    .animate(onPlay: (c) => c.repeat())
                    .scaleXY(
                        begin: 0.8,
                        end: 1.2,
                        duration: 600.ms,
                        curve: Curves.easeInOut),
                const SizedBox(width: 6),
                Text(
                  _currentStage.label,
                  style: const TextStyle(
                      color: AppColors.warning, fontSize: 11),
                ),
              ]),
            ),
        ],
      ),
      body: Column(
        children: [
          // Stage indicator
          _StageBar(
            currentStage: _currentStage,
            isComplete: _isComplete,
          ),

          // Split debate area
          Expanded(
            child: Row(
              children: [
                // Agent A
                Expanded(
                  child: _AgentDebateColumn(
                    agent: _agentA,
                    texts: _texts[widget.agentAId] ?? {},
                    currentStage: _currentStage,
                    isWinner: _userVote == widget.agentAId,
                    isLoser: _userVote == widget.agentBId,
                  ),
                ),

                // Center divider
                Container(
                  width: 1,
                  color: AppColors.borderDark,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                ),

                // Agent B
                Expanded(
                  child: _AgentDebateColumn(
                    agent: _agentB,
                    texts: _texts[widget.agentBId] ?? {},
                    currentStage: _currentStage,
                    isWinner: _userVote == widget.agentBId,
                    isLoser: _userVote == widget.agentAId,
                  ),
                ),
              ],
            ),
          ),

          // Vote bar
          if (_isComplete && _userVote == null)
            _VoteBar(
              agentA: _agentA,
              agentB: _agentB,
              onVote: (agentId) =>
                  setState(() => _userVote = agentId),
            ).animate().slideY(begin: 1, end: 0, duration: 400.ms),

          if (_userVote != null)
            _VoteResult(
              winner: AgentRegistry.get(_userVote!),
            ).animate().fadeIn(duration: 300.ms),
        ],
      ),
    );
  }
}

// ── Stage Progress Bar ────────────────────────────────────────────────────────
class _StageBar extends StatelessWidget {
  final DebateStage currentStage;
  final bool isComplete;

  const _StageBar({
    required this.currentStage,
    required this.isComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgDarkSurface,
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 8),
      child: Row(
        children: DebateStage.values.map((stage) {
          final isDone = isComplete ||
              stage.index < currentStage.index;
          final isActive = stage == currentStage && !isComplete;

          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(children: [
                AnimatedContainer(
                  duration: AppConstants.animNormal,
                  height: 3,
                  decoration: BoxDecoration(
                    color: isDone
                        ? AppColors.prismPurple
                        : isActive
                            ? AppColors.prismPurple.withOpacity(0.5)
                            : AppColors.borderDark,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stage.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 8,
                    color: isDone || isActive
                        ? AppColors.textSecondaryDark
                        : AppColors.textTertiaryDark,
                    fontWeight: isActive
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Agent Debate Column ───────────────────────────────────────────────────────
class _AgentDebateColumn extends StatelessWidget {
  final AgentModel agent;
  final Map<DebateStage, String> texts;
  final DebateStage currentStage;
  final bool isWinner;
  final bool isLoser;

  const _AgentDebateColumn({
    required this.agent,
    required this.texts,
    required this.currentStage,
    required this.isWinner,
    required this.isLoser,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppConstants.animNormal,
      decoration: BoxDecoration(
        color: isWinner
            ? agent.color.withOpacity(0.05)
            : isLoser
                ? Colors.transparent
                : Colors.transparent,
      ),
      child: Column(
        children: [
          // Agent header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isWinner
                  ? agent.color.withOpacity(0.1)
                  : AppColors.bgDarkSurface,
              border: Border(
                bottom: BorderSide(
                    color: AppColors.borderDark, width: 0.5),
              ),
            ),
            child: Row(children: [
              AgentAvatar(
                agent: agent,
                size: 28,
                isPulsing: texts[currentStage]?.isNotEmpty == true,
                isComplete: isWinner,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agent.name,
                      style: TextStyle(
                        color: agent.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      agent.role,
                      style: const TextStyle(
                        color: AppColors.textTertiaryDark,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (isWinner)
                Icon(Icons.emoji_events,
                    color: agent.color, size: 16),
            ]),
          ),

          // Scrollable content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: DebateStage.values.map((stage) {
                final text = texts[stage] ?? '';
                if (text.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stage.label.toUpperCase(),
                      style: TextStyle(
                        color: agent.color,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      text,
                      style: const TextStyle(
                        color: AppColors.textPrimaryDark,
                        fontSize: 11,
                        height: 1.6,
                      ),
                    ),
                    if (stage == currentStage &&
                        texts[stage]!.isNotEmpty)
                      TypingCursor(color: agent.color),
                    const SizedBox(height: 14),
                    const PrismDivider(opacity: 0.4),
                    const SizedBox(height: 14),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Vote Bar ──────────────────────────────────────────────────────────────────
class _VoteBar extends StatelessWidget {
  final AgentModel agentA;
  final AgentModel agentB;
  final void Function(String agentId) onVote;

  const _VoteBar({
    required this.agentA,
    required this.agentB,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgDarkSurface,
        border: const Border(
            top: BorderSide(
                color: AppColors.borderDark, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Who made the stronger case?',
            style: TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => onVote(agentA.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: agentA.color,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(agentA.name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => onVote(agentB.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: agentB.color,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(agentB.name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Vote Result ───────────────────────────────────────────────────────────────
class _VoteResult extends StatelessWidget {
  final AgentModel winner;
  const _VoteResult({required this.winner});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.bgDarkSurface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events, color: winner.color, size: 20),
          const SizedBox(width: 8),
          Text(
            '${winner.name} wins your vote',
            style: TextStyle(
              color: winner.color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

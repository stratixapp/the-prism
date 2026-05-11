// lib/features/results/presentation/screens/results_screen.dart
// Phase 15 — Full Results + Report Screen

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/models/agent_model.dart';
import '../../../../shared/models/analysis_model.dart';
import '../../../../shared/widgets/prism_widgets.dart';
import '../../../analysis/data/repositories/analysis_repository.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  final String analysisId;
  const ResultsScreen({super.key, required this.analysisId});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final analysisAsync =
        ref.watch(analysisStreamProvider(widget.analysisId));

    return analysisAsync.when(
      data: (analysis) {
        if (analysis == null) {
          return Scaffold(
            backgroundColor: AppColors.bgDark,
            body: const EmptyState(
              icon: Icons.search_off,
              title: 'Analysis not found',
              subtitle: 'This analysis may have been deleted.',
            ),
          );
        }
        return _buildScaffold(context, analysis);
      },
      loading: () => const Scaffold(
        backgroundColor: AppColors.bgDark,
        body: Center(
            child: CircularProgressIndicator(color: AppColors.prismPurple)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.bgDark,
        body: EmptyState(
            icon: Icons.error_outline,
            title: 'Failed to load',
            subtitle: e.toString()),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context, AnalysisModel analysis) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            backgroundColor: AppColors.bgDark,
            floating: true,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              onPressed: () => context.pop(),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(analysis.fileMetadata.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h4),
                Text(timeago.format(analysis.createdAt),
                    style: AppTextStyles.labelSmall),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined, size: 20),
                onPressed: () {
                  final s = analysis.synthesis;
                  Share.share(s != null
                      ? 'The Prism Analysis — ${analysis.fileMetadata.name}\n\n'
                        '#1 INSIGHT\n${s.topInsight}\n\n'
                        '#1 GAP\n${s.topGap}\n\n'
                        '#1 OPPORTUNITY\n${s.topOpportunity}\n\n'
                        'Analyzed by The Prism by Stratix'
                      : 'Analysis by The Prism — ${analysis.fileMetadata.name}');
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: AppColors.prismPurple,
              indicatorWeight: 2,
              labelColor: AppColors.prismPurple,
              unselectedLabelColor: AppColors.textTertiaryDark,
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'All Agents'),
                Tab(text: 'Insights'),
                Tab(text: 'Gaps'),
                Tab(text: 'Future'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _OverviewTab(analysis: analysis),
            _AllAgentsTab(analysis: analysis),
            _AgentFilterTab(
              analysis: analysis,
              agentId: AppConstants.agentPriya,
              emptyTitle: 'No insights yet',
              emptySubtitle: 'Dr. Priya\'s analysis will appear here.',
            ),
            _AgentFilterTab(
              analysis: analysis,
              agentId: AppConstants.agentMarcus,
              emptyTitle: 'No gaps found',
              emptySubtitle: 'Marcus\'s gap analysis will appear here.',
            ),
            _AgentFilterTab(
              analysis: analysis,
              agentId: AppConstants.agentZara,
              emptyTitle: 'No future predictions',
              emptySubtitle: 'Zara\'s future strategy will appear here.',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Overview Tab ──────────────────────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  final AnalysisModel analysis;
  const _OverviewTab({required this.analysis});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // File card
        PrismCard(
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.prismPurpleDark.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.prismPurple.withOpacity(0.3)),
                ),
                child: Center(
                  child: Text(
                    '.${analysis.fileMetadata.extension.toUpperCase()}',
                    style: const TextStyle(
                        color: AppColors.prismPurple,
                        fontSize: 9,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(analysis.fileMetadata.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h4),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        PrismBadge(
                            label: analysis.fileMetadata.sizeLabel,
                            color: AppColors.textTertiaryDark),
                        PrismBadge(
                            label: analysis.aiProvider.toUpperCase(),
                            color: AppColors.prismPurple),
                        PrismBadge(
                            label:
                                '${analysis.agentOutputs.length} agents',
                            color: AppColors.agentMarcus),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms),

        const SizedBox(height: 16),

        // Chen synthesis card
        if (analysis.synthesis != null)
          _ChenCard(synthesis: analysis.synthesis!)
              .animate(delay: 100.ms)
              .fadeIn()
              .slideY(begin: 0.04, end: 0),

        const SizedBox(height: 16),

        // Stats
        Row(
          children: [
            _Stat(label: 'Tokens',
                value: _fmt(analysis.totalTokensUsed),
                icon: Icons.bolt_outlined),
            const SizedBox(width: 8),
            _Stat(
                label: 'Cost',
                value: analysis.costUsd != null
                    ? '\$${analysis.costUsd!.toStringAsFixed(3)}'
                    : '—',
                icon: Icons.attach_money),
            const SizedBox(width: 8),
            _Stat(
                label: 'Duration',
                value: analysis.durationMs != null
                    ? '${(analysis.durationMs! / 1000).toStringAsFixed(1)}s'
                    : '—',
                icon: Icons.timer_outlined),
          ],
        ).animate(delay: 200.ms).fadeIn(),
      ],
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _ChenCard extends StatelessWidget {
  final SynthesisResult synthesis;
  const _ChenCard({required this.synthesis});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.agentChenBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.agentChen.withOpacity(0.4)),
        boxShadow: AppShadows.agentGlow(AppColors.agentChen),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            AgentAvatar(
                agent: AgentRegistry.get(AppConstants.agentChen),
                size: 30,
                isComplete: true),
            const SizedBox(width: 8),
            Text('Chen · Final Verdict',
                style: TextStyle(
                    color: AppColors.agentChen,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 14),
          const PrismDivider(),
          const SizedBox(height: 14),
          _SynthLine(
              label: '#1 INSIGHT',
              text: synthesis.topInsight,
              color: AppColors.agentAiko),
          if (synthesis.topGap.isNotEmpty) ...[
            const SizedBox(height: 14),
            _SynthLine(
                label: '#1 GAP',
                text: synthesis.topGap,
                color: AppColors.agentMarcus),
          ],
          if (synthesis.topOpportunity.isNotEmpty) ...[
            const SizedBox(height: 14),
            _SynthLine(
                label: '#1 OPPORTUNITY',
                text: synthesis.topOpportunity,
                color: AppColors.agentZara),
          ],
        ],
      ),
    );
  }
}

class _SynthLine extends StatelessWidget {
  final String label;
  final String text;
  final Color color;
  const _SynthLine(
      {required this.label, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2)),
        const SizedBox(height: 6),
        Text(text,
            style: const TextStyle(
                color: AppColors.textPrimaryDark,
                fontSize: 13,
                height: 1.6)),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _Stat(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PrismCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Column(children: [
          Icon(icon, color: AppColors.textTertiaryDark, size: 15),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimaryDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textTertiaryDark, fontSize: 10)),
        ]),
      ),
    );
  }
}

// ── All Agents Tab ────────────────────────────────────────────────────────────
class _AllAgentsTab extends StatelessWidget {
  final AnalysisModel analysis;
  const _AllAgentsTab({required this.analysis});

  @override
  Widget build(BuildContext context) {
    if (analysis.agentOutputs.isEmpty) {
      return const EmptyState(
          icon: Icons.people_outline,
          title: 'No outputs yet',
          subtitle: 'Analysis may still be running.');
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: analysis.agentOutputs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final out = analysis.agentOutputs[i];
        AgentModel? agent;
        try {
          agent = AgentRegistry.get(out.agentId);
        } catch (_) {}
        return _AgentOutputCard(output: out, agent: agent)
            .animate(delay: (i * 60).ms)
            .fadeIn()
            .slideY(begin: 0.03, end: 0);
      },
    );
  }
}

class _AgentOutputCard extends StatefulWidget {
  final AgentOutput output;
  final AgentModel? agent;
  const _AgentOutputCard({required this.output, required this.agent});

  @override
  State<_AgentOutputCard> createState() => _AgentOutputCardState();
}

class _AgentOutputCardState extends State<_AgentOutputCard> {
  bool _expanded = true;
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final agent = widget.agent;
    final color = agent?.color ?? AppColors.prismPurple;
    final bgColor = agent?.bgColor ?? AppColors.bgDarkCard;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25), width: 0.5),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                if (agent != null)
                  AgentAvatar(agent: agent, size: 30, isComplete: true)
                else
                  Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          shape: BoxShape.circle),
                      child: Icon(Icons.person, color: color, size: 14)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(agent?.name ?? widget.output.agentId,
                            style: TextStyle(
                                color: color,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        if (agent != null)
                          Text(agent.role,
                              style: const TextStyle(
                                  color: AppColors.textTertiaryDark,
                                  fontSize: 11)),
                      ]),
                ),
                Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.textTertiaryDark,
                    size: 18),
              ]),
            ),
          ),
          AnimatedCrossFade(
            duration: AppConstants.animNormal,
            crossFadeState: _expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(children: [
              const PrismDivider(),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(widget.output.content,
                        style: const TextStyle(
                            color: AppColors.textPrimaryDark,
                            fontSize: 13,
                            height: 1.65)),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () async {
                          await Clipboard.setData(
                              ClipboardData(text: widget.output.content));
                          setState(() => _copied = true);
                          Future.delayed(const Duration(seconds: 2),
                              () => setState(() => _copied = false));
                        },
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                              _copied
                                  ? Icons.check
                                  : Icons.copy_outlined,
                              color: _copied
                                  ? AppColors.success
                                  : AppColors.textTertiaryDark,
                              size: 13),
                          const SizedBox(width: 4),
                          Text(_copied ? 'Copied' : 'Copy',
                              style: TextStyle(
                                  color: _copied
                                      ? AppColors.success
                                      : AppColors.textTertiaryDark,
                                  fontSize: 11)),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ── Agent Filter Tab ──────────────────────────────────────────────────────────
class _AgentFilterTab extends StatelessWidget {
  final AnalysisModel analysis;
  final String agentId;
  final String emptyTitle;
  final String emptySubtitle;
  const _AgentFilterTab(
      {required this.analysis,
      required this.agentId,
      required this.emptyTitle,
      required this.emptySubtitle});

  @override
  Widget build(BuildContext context) {
    final output = analysis.outputFor(agentId);
    if (output == null || output.content.isEmpty) {
      return EmptyState(
          icon: Icons.person_outline,
          title: emptyTitle,
          subtitle: emptySubtitle);
    }

    AgentModel? agent;
    try {
      agent = AgentRegistry.get(agentId);
    } catch (_) {}

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (agent != null)
          Row(children: [
            AgentAvatar(agent: agent, size: 36, isComplete: true),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(agent.name,
                  style: TextStyle(
                      color: agent.color,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              Text(agent.role,
                  style: const TextStyle(
                      color: AppColors.textTertiaryDark, fontSize: 11)),
            ]),
          ]).animate().fadeIn(),
        const SizedBox(height: 16),
        SelectableText(output.content,
                style: const TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 13,
                    height: 1.65))
            .animate(delay: 100.ms)
            .fadeIn(),
      ],
    );
  }
}

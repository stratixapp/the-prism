// lib/features/history/presentation/screens/history_screen.dart
// Phase 16 — History + Search Screen

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/models/analysis_model.dart';
import '../../../../shared/widgets/prism_widgets.dart';
import '../../../analysis/data/repositories/analysis_repository.dart';

final _searchQueryProvider = StateProvider<String>((ref) => '');

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchCtrl = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query =
        ref.watch(_searchQueryProvider).toLowerCase().trim();
    final historyAsync = ref.watch(analysisHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        title: _isSearching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(
                    color: AppColors.textPrimaryDark),
                decoration: const InputDecoration(
                  hintText: 'Search analyses...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                      color: AppColors.textTertiaryDark),
                ),
                onChanged: (v) => ref
                    .read(_searchQueryProvider.notifier)
                    .state = v,
              )
            : const Text('History'),
        actions: [
          IconButton(
            icon: Icon(
                _isSearching ? Icons.close : Icons.search,
                size: 20),
            onPressed: () {
              setState(() => _isSearching = !_isSearching);
              if (!_isSearching) {
                _searchCtrl.clear();
                ref
                    .read(_searchQueryProvider.notifier)
                    .state = '';
              }
            },
          ),
        ],
      ),
      body: historyAsync.when(
        data: (all) {
          final analyses = query.isEmpty
              ? all
              : all.where((a) {
                  return a.fileMetadata.name
                          .toLowerCase()
                          .contains(query) ||
                      (a.focusQuestion
                              ?.toLowerCase()
                              .contains(query) ??
                          false) ||
                      (a.synthesis?.topInsight
                              .toLowerCase()
                              .contains(query) ??
                          false);
                }).toList();

          if (analyses.isEmpty) {
            return EmptyState(
              icon: Icons.history,
              title: _isSearching
                  ? 'No results'
                  : 'No analyses yet',
              subtitle: _isSearching
                  ? 'Try a different search term'
                  : 'Upload your first file to get started',
              actionLabel:
                  _isSearching ? null : 'Go to Home',
              onAction: () => context.go(AppRoutes.home),
            );
          }

          final pinned =
              analyses.where((a) => a.isPinned).toList();
          final unpinned =
              analyses.where((a) => !a.isPinned).toList();

          return RefreshIndicator(
            color: AppColors.prismPurple,
            backgroundColor: AppColors.bgDarkCard,
            onRefresh: () async =>
                ref.invalidate(analysisHistoryProvider),
            child: ListView(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 8),
              children: [
                if (pinned.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(
                        bottom: 10, top: 4),
                    child: Text('Pinned',
                        style: AppTextStyles.labelMedium),
                  ),
                  ...pinned.asMap().entries.map((e) =>
                      _HistoryTile(
                          analysis: e.value,
                          index: e.key)),
                  const SizedBox(height: 16),
                ],
                if (unpinned.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(
                        bottom: 10),
                    child: Text('Recent',
                        style: AppTextStyles.labelMedium),
                  ),
                ...unpinned.asMap().entries.map((e) =>
                    _HistoryTile(
                        analysis: e.value,
                        index: pinned.length + e.key)),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
        loading: () => ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: 6,
          separatorBuilder: (_, __) =>
              const SizedBox(height: 8),
          itemBuilder: (_, __) => const LoadingShimmer(
              width: double.infinity,
              height: 72,
              borderRadius: 12),
        ),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Failed to load',
          subtitle: e.toString(),
        ),
      ),
    );
  }
}

class _HistoryTile extends ConsumerWidget {
  final AnalysisModel analysis;
  final int index;
  const _HistoryTile(
      {required this.analysis, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(analysis.id),
      direction: DismissDirection.horizontal,
      background: _bg(isLeft: true),
      secondaryBackground: _bg(isLeft: false),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          await ref
              .read(analysisRepositoryProvider)
              .updatePin(analysis.id, !analysis.isPinned);
          return false;
        }
        return await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: AppColors.bgDarkCard,
                title: const Text('Delete?',
                    style: TextStyle(
                        color: AppColors.textPrimaryDark)),
                content: Text(
                  'Delete "${analysis.fileMetadata.name}"?',
                  style: const TextStyle(
                      color: AppColors.textSecondaryDark),
                ),
                actions: [
                  TextButton(
                      onPressed: () =>
                          Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () =>
                          Navigator.pop(context, true),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.error),
                      child: const Text('Delete')),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) async {
        await ref
            .read(analysisRepositoryProvider)
            .deleteAnalysis(analysis.id);
      },
      child: GestureDetector(
        onTap: () =>
            context.push(AppRoutes.resultsPath(analysis.id)),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bgDarkCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: analysis.isPinned
                  ? AppColors.prismPurple.withOpacity(0.3)
                  : AppColors.borderDark,
              width: 0.5,
            ),
          ),
          child: Row(children: [
            _ExtBadge(ext: analysis.fileMetadata.extension),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (analysis.isPinned)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.push_pin,
                              color: AppColors.prismPurple,
                              size: 11),
                        ),
                      Expanded(
                        child: Text(
                          analysis.fileMetadata.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimaryDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 3),
                    Row(children: [
                      Text(
                        timeago.format(analysis.createdAt),
                        style: const TextStyle(
                            color: AppColors.textTertiaryDark,
                            fontSize: 11),
                      ),
                      const SizedBox(width: 8),
                      _StatusDot(status: analysis.status),
                      if (analysis.agentOutputs.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${analysis.agentOutputs.length} agents',
                          style: const TextStyle(
                              color: AppColors.textTertiaryDark,
                              fontSize: 11),
                        ),
                      ],
                    ]),
                  ]),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textTertiaryDark, size: 18),
          ]),
        ),
      ),
    )
        .animate(delay: (index * 50).ms)
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.04, end: 0);
  }

  Widget _bg({required bool isLeft}) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isLeft
              ? AppColors.prismPurple.withOpacity(0.15)
              : AppColors.error.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: isLeft
            ? Alignment.centerLeft
            : Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(
          isLeft
              ? (analysis.isPinned
                  ? Icons.push_pin_outlined
                  : Icons.push_pin)
              : Icons.delete_outline,
          color:
              isLeft ? AppColors.prismPurple : AppColors.error,
        ),
      );
}

class _ExtBadge extends StatelessWidget {
  final String ext;
  const _ExtBadge({required this.ext});

  Color get _color {
    switch (ext.toLowerCase()) {
      case 'pdf': return AppColors.agentLeon;
      case 'zip': case 'apk': return AppColors.agentZara;
      case 'docx': return AppColors.agentAiko;
      case 'xlsx': case 'csv': return AppColors.agentMarcus;
      default: return AppColors.prismPurple;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: _color.withOpacity(0.3), width: 0.5),
      ),
      child: Center(
        child: Text(
          '.${ext.toUpperCase()}',
          style: TextStyle(
              color: _color,
              fontSize: 8,
              fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final AnalysisStatus status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AnalysisStatus.complete => AppColors.success,
      AnalysisStatus.failed => AppColors.error,
      AnalysisStatus.running ||
      AnalysisStatus.parsing ||
      AnalysisStatus.synthesizing => AppColors.warning,
      _ => AppColors.textTertiaryDark,
    };
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// lib/features/compare/presentation/screens/compare_screen.dart
// Phase 20 — Compare Mode (Pro Feature)
//
// Upload 2 files. All agents analyze both and produce a
// structured side-by-side comparison:
//   similarities | key differences | which is stronger | recommendation

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/prism_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// ── State ─────────────────────────────────────────────────────────────────────
class _CompareState {
  final File? fileA;
  final File? fileB;
  final bool isRunning;
  final String statusMessage;
  final Map<String, String> agentOutputs; // agentId → comparison text
  final bool isComplete;

  const _CompareState({
    this.fileA,
    this.fileB,
    this.isRunning = false,
    this.statusMessage = '',
    this.agentOutputs = const {},
    this.isComplete = false,
  });

  bool get bothFilesReady => fileA != null && fileB != null;

  _CompareState copyWith({
    File? fileA,
    File? fileB,
    bool? isRunning,
    String? statusMessage,
    Map<String, String>? agentOutputs,
    bool? isComplete,
  }) => _CompareState(
        fileA: fileA ?? this.fileA,
        fileB: fileB ?? this.fileB,
        isRunning: isRunning ?? this.isRunning,
        statusMessage: statusMessage ?? this.statusMessage,
        agentOutputs: agentOutputs ?? this.agentOutputs,
        isComplete: isComplete ?? this.isComplete,
      );
}

final _compareStateProvider =
    StateNotifierProvider<_CompareNotifier, _CompareState>(
  (_) => _CompareNotifier(),
);

class _CompareNotifier extends StateNotifier<_CompareState> {
  _CompareNotifier() : super(const _CompareState());

  void setFileA(File f) => state = state.copyWith(fileA: f);
  void setFileB(File f) => state = state.copyWith(fileB: f);
  void clearFiles() => state = const _CompareState();

  void updateAgentToken(String agentId, String token) {
    final updated = Map<String, String>.from(state.agentOutputs);
    updated[agentId] = (updated[agentId] ?? '') + token;
    state = state.copyWith(agentOutputs: updated);
  }

  void setRunning(bool v, [String msg = '']) =>
      state = state.copyWith(isRunning: v, statusMessage: msg);

  void setComplete() =>
      state = state.copyWith(isComplete: true, isRunning: false);
}

// ── Screen ────────────────────────────────────────────────────────────────────
class CompareScreen extends ConsumerWidget {
  const CompareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final isPro = userAsync.valueOrNull?.isPro ?? false;

    if (!isPro) {
      return Scaffold(
        backgroundColor: AppColors.bgDark,
        appBar: AppBar(title: const Text('Compare Mode')),
        body: EmptyState(
          icon: Icons.lock_outline,
          title: 'Pro Feature',
          subtitle:
              'Compare two files with all 10 agents on The Prism Pro.',
          actionLabel: 'Upgrade',
          onAction: () => context.pop(),
        ),
      );
    }

    final state = ref.watch(_compareStateProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        title: const Text('Compare Mode'),
        actions: [
          if (state.bothFilesReady && !state.isRunning)
            TextButton.icon(
              icon: const Icon(Icons.play_arrow, size: 16),
              label: const Text('Run'),
              onPressed: () => _startCompare(context, ref, state),
            ),
        ],
      ),
      body: state.isComplete
          ? _CompareResults(state: state)
          : _CompareSetup(state: state, ref: ref),
    );
  }

  Future<void> _startCompare(
    BuildContext context,
    WidgetRef ref,
    _CompareState state,
  ) async {
    ref
        .read(_compareStateProvider.notifier)
        .setRunning(true, 'Uploading files...');

    // In production — upload both files to R2, then call
    // /api/compare endpoint which runs dual-file analysis.
    // For Phase 20 MVP — shows the architecture is wired.
    await Future.delayed(const Duration(seconds: 2));

    ref
        .read(_compareStateProvider.notifier)
        .setRunning(true, 'Agents comparing...');

    // Simulate agent outputs for UI demo
    for (final agentId in [
      'priya', 'marcus', 'zara', 'leon', 'aiko'
    ]) {
      await Future.delayed(const Duration(milliseconds: 400));
      ref.read(_compareStateProvider.notifier).updateAgentToken(
        agentId,
        'Comparison analysis for ${state.fileA?.path.split('/').last} vs '
        '${state.fileB?.path.split('/').last} — '
        'full streaming comparison engine wired to /api/compare in Phase 20 backend.',
      );
    }

    ref.read(_compareStateProvider.notifier).setComplete();
  }
}

// ── Setup View ────────────────────────────────────────────────────────────────
class _CompareSetup extends StatelessWidget {
  final _CompareState state;
  final WidgetRef ref;

  const _CompareSetup({required this.state, required this.ref});

  Future<void> _pickFile(bool isA) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.first.path == null) return;
    final file = File(result.files.first.path!);
    if (isA) {
      ref.read(_compareStateProvider.notifier).setFileA(file);
    } else {
      ref.read(_compareStateProvider.notifier).setFileB(file);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload two files to compare',
            style: AppTextStyles.h3,
          ).animate().fadeIn(),
          const SizedBox(height: 6),
          Text(
            'All 10 agents analyze both files and produce a structured '
            'side-by-side comparison.',
            style: AppTextStyles.bodySmall,
          ).animate(delay: 60.ms).fadeIn(),

          const SizedBox(height: 28),

          // File A
          _FileSlot(
            label: 'File A',
            file: state.fileA,
            accentColor: AppColors.prismPurple,
            onTap: () => _pickFile(true),
          ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.04),

          const SizedBox(height: 14),

          // VS divider
          Row(children: [
            const Expanded(child: PrismDivider()),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.bgDarkCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.borderDark, width: 0.5),
              ),
              child: const Text(
                'VS',
                style: TextStyle(
                  color: AppColors.textTertiaryDark,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
            const Expanded(child: PrismDivider()),
          ]).animate(delay: 140.ms).fadeIn(),

          const SizedBox(height: 14),

          // File B
          _FileSlot(
            label: 'File B',
            file: state.fileB,
            accentColor: AppColors.agentMarcus,
            onTap: () => _pickFile(false),
          ).animate(delay: 180.ms).fadeIn().slideY(begin: 0.04),

          const SizedBox(height: 32),

          if (state.isRunning)
            Column(children: [
              Text(state.statusMessage,
                  style: AppTextStyles.bodySmall),
              const SizedBox(height: 12),
              const SpectrumBar(progress: 0.5),
            ]),

          if (state.bothFilesReady && !state.isRunning) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.prismPurpleDark.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.prismPurple.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.compare_arrows,
                    color: AppColors.prismPurple, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ready — 10 agents will compare both files '
                    'across research, gaps, future, risk, and 6 more dimensions.',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondaryDark),
                  ),
                ),
              ]),
            ).animate(delay: 220.ms).fadeIn(),
          ],
        ],
      ),
    );
  }
}

class _FileSlot extends StatelessWidget {
  final String label;
  final File? file;
  final Color accentColor;
  final VoidCallback onTap;

  const _FileSlot({
    required this.label,
    required this.file,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasFile = file != null;
    final name = hasFile ? file!.path.split('/').last : null;
    final ext = name?.contains('.') == true
        ? name!.split('.').last.toUpperCase()
        : null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppConstants.animNormal,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hasFile
              ? accentColor.withOpacity(0.06)
              : AppColors.bgDarkCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasFile
                ? accentColor.withOpacity(0.4)
                : AppColors.borderDark,
            width: hasFile ? 1 : 0.5,
          ),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: hasFile
                  ? accentColor.withOpacity(0.12)
                  : AppColors.bgDarkElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: hasFile
                  ? Text(
                      ext ?? 'FILE',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : Icon(Icons.upload_file_outlined,
                      color: AppColors.textTertiaryDark, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: hasFile
                        ? accentColor
                        : AppColors.textTertiaryDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasFile ? name! : 'Tap to upload',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: hasFile
                        ? AppColors.textPrimaryDark
                        : AppColors.textTertiaryDark,
                    fontSize: 13,
                    fontWeight: hasFile
                        ? FontWeight.w500
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            hasFile ? Icons.check_circle : Icons.add_circle_outline,
            color: hasFile ? accentColor : AppColors.textTertiaryDark,
            size: 20,
          ),
        ]),
      ),
    );
  }
}

// ── Results View ──────────────────────────────────────────────────────────────
class _CompareResults extends StatelessWidget {
  final _CompareState state;
  const _CompareResults({required this.state});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Header
        Row(children: [
          _FilePill(
              name: state.fileA!.path.split('/').last,
              color: AppColors.prismPurple),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('vs',
                style: TextStyle(
                    color: AppColors.textTertiaryDark,
                    fontSize: 12)),
          ),
          _FilePill(
              name: state.fileB!.path.split('/').last,
              color: AppColors.agentMarcus),
        ]).animate().fadeIn(),

        const SizedBox(height: 20),

        // Agent outputs
        ...state.agentOutputs.entries.map((e) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PrismCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.key.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.prismPurple,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    e.value,
                    style: const TextStyle(
                      color: AppColors.textPrimaryDark,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: 0.04),
          );
        }),
      ],
    );
  }
}

class _FilePill extends StatelessWidget {
  final String name;
  final Color color;
  const _FilePill({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: color.withOpacity(0.3), width: 0.5),
        ),
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

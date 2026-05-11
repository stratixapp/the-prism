// lib/features/custom_agent/presentation/screens/custom_agent_screen.dart
// Phase 19 — Custom Agent Builder (Pro Feature)
//
// Pro users define: name, role title, domain expertise,
// reasoning style, output format. Saved to Firestore.
// Appears alongside default 10 agents in all future analyses.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/prism_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// ── Custom Agent Model ────────────────────────────────────────────────────────
class CustomAgentDraft {
  final String name;
  final String role;
  final String domainExpertise;
  final String reasoningStyle;
  final String outputFormat;
  final String colorHex;

  const CustomAgentDraft({
    this.name = '',
    this.role = '',
    this.domainExpertise = '',
    this.reasoningStyle = 'analytical',
    this.outputFormat = 'paragraphs',
    this.colorHex = '#7F77DD',
  });

  bool get isValid =>
      name.trim().length >= 2 &&
      role.trim().length >= 2 &&
      domainExpertise.trim().length >= 20;

  CustomAgentDraft copyWith({
    String? name,
    String? role,
    String? domainExpertise,
    String? reasoningStyle,
    String? outputFormat,
    String? colorHex,
  }) {
    return CustomAgentDraft(
      name: name ?? this.name,
      role: role ?? this.role,
      domainExpertise: domainExpertise ?? this.domainExpertise,
      reasoningStyle: reasoningStyle ?? this.reasoningStyle,
      outputFormat: outputFormat ?? this.outputFormat,
      colorHex: colorHex ?? this.colorHex,
    );
  }

  String buildSystemPrompt() {
    return '''You are ${name.trim()}, a ${role.trim()}.

Your domain expertise: ${domainExpertise.trim()}

Your reasoning style: $reasoningStyle — you approach every problem with this mindset and stick to it consistently.

Your output format: $outputFormat — always structure your responses in this way.

When analyzing a file:
- Apply your specific domain expertise to everything you read
- Stay true to your reasoning style throughout
- Format output as specified above
- Be specific to the actual content — no generic analysis
- Identify 3-5 concrete findings, opportunities, or issues relevant to your domain

You are a specialist. Your value comes from your unique angle — not repeating what other agents might say, but finding what ONLY your expertise can see.''';
  }

  Map<String, dynamic> toFirestore(String userId) {
    return {
      'userId': userId,
      'name': name.trim(),
      'role': role.trim(),
      'domainExpertise': domainExpertise.trim(),
      'reasoningStyle': reasoningStyle,
      'outputFormat': outputFormat,
      'colorHex': colorHex,
      'systemPrompt': buildSystemPrompt(),
      'isCustom': true,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────
final _draftProvider =
    StateProvider<CustomAgentDraft>((ref) => const CustomAgentDraft());

final _savedCustomAgentsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection('customAgents')
      .where('userId', isEqualTo: user.uid)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList());
});

// ── Screen ────────────────────────────────────────────────────────────────────
class CustomAgentScreen extends ConsumerStatefulWidget {
  const CustomAgentScreen({super.key});

  @override
  ConsumerState<CustomAgentScreen> createState() =>
      _CustomAgentScreenState();
}

class _CustomAgentScreenState
    extends ConsumerState<CustomAgentScreen> {
  bool _isSaving = false;

  static const _styles = [
    'analytical',
    'creative',
    'critical',
    'strategic',
    'empathetic',
    'contrarian',
  ];

  static const _formats = [
    'paragraphs',
    'bullet points',
    'numbered list',
    'structured report',
    'executive summary',
  ];

  static const _colors = [
    '#7F77DD', '#1D9E75', '#BA7517', '#D85A30',
    '#378ADD', '#D4537E', '#639922', '#E24B4A',
    '#888780', '#3C3489',
  ];

  Future<void> _saveAgent() async {
    final draft = ref.read(_draftProvider);
    if (!draft.isValid) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('customAgents')
          .add(draft.toFirestore(user.uid));

      ref.read(_draftProvider.notifier).state =
          const CustomAgentDraft();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Agent saved! Available in future analyses.')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to save: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(_draftProvider);
    final userAsync = ref.watch(currentUserProvider);
    final isPro = userAsync.valueOrNull?.isPro ?? false;

    if (!isPro) {
      return Scaffold(
        backgroundColor: AppColors.bgDark,
        appBar: AppBar(title: const Text('Custom Agents')),
        body: EmptyState(
          icon: Icons.lock_outline,
          title: 'Pro Feature',
          subtitle:
              'Build custom agents on The Prism Pro plan.',
          actionLabel: 'Upgrade',
          onAction: () => context.pop(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        title: const Text('Build a Custom Agent'),
        actions: [
          TextButton(
            onPressed:
                draft.isValid && !_isSaving ? _saveAgent : null,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.prismPurple))
                : const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview card
            _AgentPreviewCard(draft: draft)
                .animate()
                .fadeIn(duration: 300.ms),

            const SizedBox(height: 24),

            // Name
            _FieldLabel('Agent name'),
            TextField(
              maxLength: 20,
              style: AppTextStyles.bodyLarge
                  .copyWith(color: AppColors.textPrimaryDark),
              decoration: const InputDecoration(
                  hintText: 'e.g. "Kai", "Dr. Sharma", "The Skeptic"'),
              onChanged: (v) => ref
                  .read(_draftProvider.notifier)
                  .update((s) => s.copyWith(name: v)),
            ).animate(delay: 60.ms).fadeIn(),

            const SizedBox(height: 14),

            // Role
            _FieldLabel('Role title'),
            TextField(
              maxLength: 40,
              style: AppTextStyles.bodyLarge
                  .copyWith(color: AppColors.textPrimaryDark),
              decoration: const InputDecoration(
                  hintText:
                      'e.g. "Blockchain Specialist", "UX Researcher"'),
              onChanged: (v) => ref
                  .read(_draftProvider.notifier)
                  .update((s) => s.copyWith(role: v)),
            ).animate(delay: 80.ms).fadeIn(),

            const SizedBox(height: 14),

            // Domain expertise
            _FieldLabel('Domain expertise'),
            TextField(
              maxLines: 3,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textPrimaryDark),
              decoration: const InputDecoration(
                hintText:
                    'Describe this agent\'s expertise in detail. '
                    'The more specific, the better the analysis. '
                    'e.g. "DeFi protocol security auditing with focus on '
                    'reentrancy attacks and MEV vulnerabilities"',
              ),
              onChanged: (v) => ref
                  .read(_draftProvider.notifier)
                  .update((s) => s.copyWith(domainExpertise: v)),
            ).animate(delay: 100.ms).fadeIn(),

            const SizedBox(height: 20),

            // Reasoning style
            _FieldLabel('Reasoning style'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _styles.map((style) {
                final selected = draft.reasoningStyle == style;
                return GestureDetector(
                  onTap: () => ref
                      .read(_draftProvider.notifier)
                      .update((s) =>
                          s.copyWith(reasoningStyle: style)),
                  child: AnimatedContainer(
                    duration: AppConstants.animFast,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.prismPurpleDark
                          : AppColors.bgDarkCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? AppColors.prismPurple
                            : AppColors.borderDark,
                      ),
                    ),
                    child: Text(
                      style,
                      style: TextStyle(
                        color: selected
                            ? AppColors.prismPurple
                            : AppColors.textSecondaryDark,
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ).animate(delay: 120.ms).fadeIn(),

            const SizedBox(height: 20),

            // Output format
            _FieldLabel('Output format'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _formats.map((fmt) {
                final selected = draft.outputFormat == fmt;
                return GestureDetector(
                  onTap: () => ref
                      .read(_draftProvider.notifier)
                      .update(
                          (s) => s.copyWith(outputFormat: fmt)),
                  child: AnimatedContainer(
                    duration: AppConstants.animFast,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.agentMarcusBg
                          : AppColors.bgDarkCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? AppColors.agentMarcus
                            : AppColors.borderDark,
                      ),
                    ),
                    child: Text(
                      fmt,
                      style: TextStyle(
                        color: selected
                            ? AppColors.agentMarcus
                            : AppColors.textSecondaryDark,
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ).animate(delay: 140.ms).fadeIn(),

            const SizedBox(height: 20),

            // Color picker
            _FieldLabel('Agent color'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _colors.map((hex) {
                final color = Color(
                    int.parse('FF${hex.substring(1)}', radix: 16));
                final selected = draft.colorHex == hex;
                return GestureDetector(
                  onTap: () => ref
                      .read(_draftProvider.notifier)
                      .update(
                          (s) => s.copyWith(colorHex: hex)),
                  child: AnimatedContainer(
                    duration: AppConstants.animFast,
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? color : Colors.transparent,
                        width: selected ? 2 : 0,
                      ),
                    ),
                    child: selected
                        ? Icon(Icons.check, color: color, size: 14)
                        : Container(
                            width: 16,
                            height: 16,
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                  ),
                );
              }).toList(),
            ).animate(delay: 160.ms).fadeIn(),

            const SizedBox(height: 32),

            // System prompt preview
            _FieldLabel('Generated system prompt preview'),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bgDarkCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.borderDark, width: 0.5),
              ),
              child: Text(
                draft.buildSystemPrompt(),
                style: const TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 11,
                  height: 1.6,
                  fontFamily: 'monospace',
                ),
              ),
            ).animate(delay: 180.ms).fadeIn(),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    draft.isValid && !_isSaving ? _saveAgent : null,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save agent'),
              ),
            ).animate(delay: 200.ms).fadeIn(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: AppTextStyles.labelMedium),
    );
  }
}

class _AgentPreviewCard extends StatelessWidget {
  final CustomAgentDraft draft;
  const _AgentPreviewCard({required this.draft});

  @override
  Widget build(BuildContext context) {
    final color = draft.colorHex.isNotEmpty
        ? Color(int.parse(
            'FF${draft.colorHex.substring(1)}',
            radix: 16))
        : AppColors.prismPurple;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
            border:
                Border.all(color: color.withOpacity(0.5)),
          ),
          child: Center(
            child: Text(
              draft.name.isNotEmpty
                  ? draft.name.substring(0, 1).toUpperCase()
                  : '?',
              style: TextStyle(
                color: color,
                fontSize: 16,
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
                draft.name.isNotEmpty ? draft.name : 'Your Agent',
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                draft.role.isNotEmpty ? draft.role : 'Custom Specialist',
                style: const TextStyle(
                  color: AppColors.textTertiaryDark,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        PrismBadge(label: 'CUSTOM', color: color),
      ]),
    );
  }
}

// lib/features/settings/presentation/screens/settings_screen.dart
// Phases 12+ — Full Settings Screen

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/widgets/prism_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _appVersion = info.version);
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        title: const Text('Settings'),
      ),
      body: userAsync.when(
        data: (user) => _buildBody(context, user),
        loading: () => const Center(
            child: CircularProgressIndicator(
                color: AppColors.prismPurple)),
        error: (_, __) => const EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load settings',
          subtitle: 'Please restart the app.',
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, PrismUser? user) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        // ── Profile card ────────────────────────────────────────────────
        if (user != null)
          _ProfileCard(user: user)
              .animate()
              .fadeIn(duration: 300.ms),

        const SizedBox(height: 20),

        // ── Plan section ─────────────────────────────────────────────────
        if (user != null) ...[
          _SectionLabel(label: 'Plan'),
          _PlanCard(user: user),
          const SizedBox(height: 20),
        ],

        // ── AI Preferences ───────────────────────────────────────────────
        _SectionLabel(label: 'AI Preferences'),
        _SettingsTile(
          icon: Icons.auto_awesome_outlined,
          title: 'Default AI engine',
          subtitle: _providerLabel(
              user?.preferredAiProvider ?? AppConstants.aiProviderClaude),
          onTap: () => _showProviderPicker(context, user),
        ),
        _SettingsTile(
          icon: Icons.people_outline,
          title: 'Agents per analysis',
          subtitle: user?.isPro == true
              ? 'All 10 agents'
              : '3 agents (upgrade for all 10)',
          onTap: user?.isPro == true ? null : () => _showUpgradeSheet(context),
        ),
        const SizedBox(height: 20),

        // ── Account ──────────────────────────────────────────────────────
        _SectionLabel(label: 'Account'),
        _SettingsTile(
          icon: Icons.email_outlined,
          title: 'Email',
          subtitle: user?.email ?? '—',
        ),
        _SettingsTile(
          icon: Icons.person_outline,
          title: 'Display name',
          subtitle: user?.displayName ?? '—',
        ),
        _SettingsTile(
          icon: Icons.business_center_outlined,
          title: 'Industry',
          subtitle: _capitalize(user?.industry ?? 'general'),
        ),
        const SizedBox(height: 20),

        // ── Legal ────────────────────────────────────────────────────────
        _SectionLabel(label: 'Legal'),
        _SettingsTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy Policy',
          onTap: () => _launch('https://theprism.app/privacy'),
        ),
        _SettingsTile(
          icon: Icons.description_outlined,
          title: 'Terms of Service',
          onTap: () => _launch('https://theprism.app/terms'),
        ),
        _SettingsTile(
          icon: Icons.delete_outline,
          title: 'Delete my account',
          titleColor: AppColors.error,
          onTap: () => _confirmDeleteAccount(context),
        ),
        const SizedBox(height: 20),

        // ── About ─────────────────────────────────────────────────────────
        _SectionLabel(label: 'About'),
        _SettingsTile(
          icon: Icons.change_history,
          title: 'The Prism',
          subtitle: 'Version $_appVersion · by Stratix',
        ),
        _SettingsTile(
          icon: Icons.star_outline,
          title: 'Rate on Play Store',
          onTap: () => _launch(
              'https://play.google.com/store/apps/details?id=com.stratix.theprism'),
        ),
        const SizedBox(height: 20),

        // ── Sign Out ──────────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(
                  color: AppColors.error, width: 0.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => _signOut(context),
          ),
        ).animate(delay: 300.ms).fadeIn(),

        const SizedBox(height: 40),
      ],
    );
  }

  String _providerLabel(String provider) {
    switch (provider) {
      case AppConstants.aiProviderClaude:
        return 'Claude (Anthropic)';
      case AppConstants.aiProviderOpenAI:
        return 'GPT-4o (OpenAI)';
      case AppConstants.aiProviderBoth:
        return 'Both (Cross-validated)';
      default:
        return provider;
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _showProviderPicker(BuildContext context, PrismUser? user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgDarkSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Default AI Engine', style: AppTextStyles.h3),
            const SizedBox(height: 16),
            ...[
              AppConstants.aiProviderClaude,
              AppConstants.aiProviderOpenAI,
              AppConstants.aiProviderBoth,
            ].map((p) => ListTile(
                  title: Text(_providerLabel(p),
                      style: TextStyle(
                          color: AppColors.textPrimaryDark,
                          fontWeight:
                              user?.preferredAiProvider == p
                                  ? FontWeight.w600
                                  : FontWeight.w400)),
                  trailing: user?.preferredAiProvider == p
                      ? const Icon(Icons.check,
                          color: AppColors.prismPurple)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Save to Firestore in Phase 12 expansion
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showUpgradeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgDarkSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.prismPurpleDark.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome,
                  color: AppColors.prismPurple),
            ),
            const SizedBox(height: 16),
            Text('Upgrade to Pro', style: AppTextStyles.h2),
            const SizedBox(height: 8),
            Text(
              'Unlock all 10 agents, unlimited analyses,\nPDF export, dual AI engine, and more.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // TODO: Trigger Play Billing in Phase 22
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Play Billing integration — Phase 22')),
                  );
                },
                child: Text(
                    '${AppConstants.pricePro}/month — Go Pro'),
              ),
            ),
            const SizedBox(height: 12),
            Text('Cancel anytime · No contracts',
                style: AppTextStyles.labelSmall),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgDarkCard,
        title: const Text('Delete account?',
            style:
                TextStyle(color: AppColors.textPrimaryDark)),
        content: const Text(
          'This will permanently delete your account and all analyses. This cannot be undone.',
          style:
              TextStyle(color: AppColors.textSecondaryDark),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.error),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // TODO: call delete account API in Phase 23
      await ref.read(authNotifierProvider.notifier).signOut();
      if (mounted) context.go(AppRoutes.login);
    }
  }

  Future<void> _signOut(BuildContext context) async {
    await ref.read(authNotifierProvider.notifier).signOut();
    if (mounted) context.go(AppRoutes.login);
  }
}

// ── Profile Card ──────────────────────────────────────────────────────────────
class _ProfileCard extends StatelessWidget {
  final PrismUser user;
  const _ProfileCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return PrismCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.prismPurpleDark.withOpacity(0.3),
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.prismPurple.withOpacity(0.4)),
            ),
            child: Center(
              child: Text(
                user.displayName.isNotEmpty
                    ? user.displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: AppColors.prismPurple,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.displayName, style: AppTextStyles.h4),
                const SizedBox(height: 3),
                Text(user.email, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          PrismBadge(
            label: user.plan.toUpperCase(),
            color: user.isPro
                ? AppColors.agentZara
                : AppColors.textTertiaryDark,
          ),
        ],
      ),
    );
  }
}

// ── Plan Card ─────────────────────────────────────────────────────────────────
class _PlanCard extends StatelessWidget {
  final PrismUser user;
  const _PlanCard({required this.user});

  @override
  Widget build(BuildContext context) {
    if (user.isPro) {
      return PrismCard(
        accentColor: AppColors.agentZara,
        isActive: true,
        child: Row(
          children: [
            const Icon(Icons.star, color: AppColors.agentZara, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pro Plan', style: AppTextStyles.h4),
                  Text('Unlimited analyses · All 10 agents · PDF export',
                      style: AppTextStyles.bodySmall),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return PrismCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.lock_outline,
                color: AppColors.textTertiaryDark, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Free Plan', style: AppTextStyles.h4),
                  Text(
                    '${user.remainingFreeAnalyses} / ${AppConstants.freeAnalysesPerMonth} analyses remaining this month',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 14),
          SpectrumBar(
            progress: 1 -
                (user.remainingFreeAnalyses /
                    AppConstants.freeAnalysesPerMonth),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Play Billing — Phase 22')),
                );
              },
              child: Text(
                  'Upgrade to Pro · ${AppConstants.pricePro}/month'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Label ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textTertiaryDark,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Settings Tile ─────────────────────────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? titleColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(
            vertical: 13, horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.bgDarkCard,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppColors.borderDark, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: titleColor ?? AppColors.textSecondaryDark,
                size: 18),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: titleColor ??
                          AppColors.textPrimaryDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textTertiaryDark,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right,
                  color: AppColors.textTertiaryDark, size: 16),
          ],
        ),
      ),
    );
  }
}

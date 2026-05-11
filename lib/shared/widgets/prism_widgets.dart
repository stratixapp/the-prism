// lib/shared/widgets/prism_widgets.dart
// Phase 11 — Prism Design System
// Reusable component library used across all screens.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/app_constants.dart';
import '../models/agent_model.dart';

// ── PrismCard ─────────────────────────────────────────────────────────────────
/// Standard dark card with optional border accent color
class PrismCard extends StatelessWidget {
  final Widget child;
  final Color? accentColor;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final bool isActive;

  const PrismCard({
    super.key,
    required this.child,
    this.accentColor,
    this.padding,
    this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppConstants.animFast,
        padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.bgDarkCard,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isActive
                ? (accentColor ?? AppColors.prismPurple)
                : AppColors.borderDark,
            width: isActive ? 1 : 0.5,
          ),
          boxShadow: isActive && accentColor != null
              ? AppShadows.agentGlow(accentColor!)
              : null,
        ),
        child: child,
      ),
    );
  }
}

// ── SpectrumBar ───────────────────────────────────────────────────────────────
/// Animated progress bar that fills with the spectrum gradient
class SpectrumBar extends StatelessWidget {
  final double progress; // 0.0 → 1.0
  final double height;
  final bool animated;

  const SpectrumBar({
    super.key,
    required this.progress,
    this.height = 3,
    this.animated = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: height,
          width: constraints.maxWidth,
          decoration: BoxDecoration(
            color: AppColors.borderDark,
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: animated ? AppConstants.animNormal : Duration.zero,
              width: constraints.maxWidth * progress.clamp(0.0, 1.0),
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height / 2),
                gradient: const LinearGradient(
                  colors: AppColors.spectrumGradient,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── AgentAvatar ───────────────────────────────────────────────────────────────
/// Circular agent avatar with initials and spectrum color
class AgentAvatar extends StatelessWidget {
  final AgentModel agent;
  final double size;
  final bool isPulsing;
  final bool isComplete;

  const AgentAvatar({
    super.key,
    required this.agent,
    this.size = 40,
    this.isPulsing = false,
    this.isComplete = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: agent.bgColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: agent.color.withOpacity(isPulsing ? 0.8 : 0.4),
          width: isPulsing ? 1.5 : 1,
        ),
        boxShadow: isPulsing ? AppShadows.agentGlow(agent.color) : null,
      ),
      child: isComplete
          ? Icon(Icons.check, color: agent.color, size: size * 0.4)
          : Center(
              child: Text(
                agent.initials,
                style: TextStyle(
                  color: agent.color,
                  fontSize: size * 0.28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
    );

    if (isPulsing) {
      avatar = avatar
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(
            begin: 1.0,
            end: 1.05,
            duration: 800.ms,
            curve: Curves.easeInOut,
          );
    }

    return avatar;
  }
}

// ── PrismBadge ────────────────────────────────────────────────────────────────
/// Small label badge used for plan, status, agent role indicators
class PrismBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color? bgColor;
  final IconData? icon;

  const PrismBadge({
    super.key,
    required this.label,
    required this.color,
    this.bgColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor ?? color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 10),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── SectionHeader ─────────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.h4),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(action!,
                style: TextStyle(color: AppColors.prismPurple, fontSize: 13)),
          ),
      ],
    );
  }
}

// ── PrismDivider ──────────────────────────────────────────────────────────────
class PrismDivider extends StatelessWidget {
  final double opacity;
  const PrismDivider({super.key, this.opacity = 1.0});

  @override
  Widget build(BuildContext context) {
    return Divider(
      color: AppColors.dividerDark.withOpacity(opacity),
      thickness: 0.5,
      height: 1,
    );
  }
}

// ── LoadingShimmer ────────────────────────────────────────────────────────────
class LoadingShimmer extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const LoadingShimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = AppRadius.sm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.bgDarkCard,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(
          duration: 1200.ms,
          color: AppColors.borderDark,
        );
  }
}

// ── EmptyState ────────────────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.bgDarkCard,
                shape: BoxShape.circle,
                border:
                    Border.all(color: AppColors.borderDark, width: 0.5),
              ),
              child: Icon(icon,
                  color: AppColors.textTertiaryDark, size: 28),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title,
                style: AppTextStyles.h4, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(subtitle,
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── TypingCursor ──────────────────────────────────────────────────────────────
/// Blinking cursor shown while an agent is streaming
class TypingCursor extends StatelessWidget {
  final Color color;
  const TypingCursor({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fadeIn(duration: 500.ms)
        .fadeOut(duration: 500.ms);
  }
}

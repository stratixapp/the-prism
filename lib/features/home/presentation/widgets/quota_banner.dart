// lib/features/home/presentation/widgets/quota_banner.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_model.dart';

class QuotaBanner extends StatelessWidget {
  final PrismUser user;
  const QuotaBanner({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final remaining = user.remainingFreeAnalyses;
    final isUrgent = remaining <= 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isUrgent
            ? AppColors.error.withOpacity(0.08)
            : AppColors.prismPurpleDark.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isUrgent
              ? AppColors.error.withOpacity(0.3)
              : AppColors.prismPurple.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isUrgent
                ? Icons.warning_amber_outlined
                : Icons.info_outline,
            color: isUrgent
                ? AppColors.error
                : AppColors.prismPurple,
            size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              remaining == 0
                  ? 'No free analyses left this month'
                  : '$remaining free ${remaining == 1 ? 'analysis' : 'analyses'} remaining',
              style: TextStyle(
                color: isUrgent
                    ? AppColors.error
                    : AppColors.textSecondaryDark,
                fontSize: 12,
              ),
            ),
          ),
          TextButton(
            onPressed: () => context.push(AppRoutes.settings),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
            ),
            child: const Text(
              'Upgrade',
              style: TextStyle(
                color: AppColors.prismPurple,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

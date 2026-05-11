// lib/features/home/presentation/widgets/recent_analysis_card.dart

import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/analysis_model.dart';

class RecentAnalysisCard extends StatelessWidget {
  final AnalysisModel analysis;
  final VoidCallback onTap;

  const RecentAnalysisCard({
    super.key,
    required this.analysis,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgDarkCard,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppColors.borderDark, width: 0.5),
        ),
        child: Row(
          children: [
            _ExtBadge(ext: analysis.fileMetadata.extension),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    analysis.fileMetadata.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimaryDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(children: [
                    Text(
                      timeago.format(analysis.createdAt),
                      style: const TextStyle(
                          color: AppColors.textTertiaryDark,
                          fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(status: analysis.status),
                    if (analysis.isComplete &&
                        analysis.agentOutputs.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${analysis.agentOutputs.length} agents',
                        style: const TextStyle(
                            color: AppColors.textTertiaryDark,
                            fontSize: 11),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right,
                color: AppColors.textTertiaryDark, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ExtBadge extends StatelessWidget {
  final String ext;
  const _ExtBadge({required this.ext});

  Color get _color {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return AppColors.agentLeon;
      case 'zip':
      case 'apk':
        return AppColors.agentZara;
      case 'docx':
        return AppColors.agentAiko;
      case 'xlsx':
      case 'csv':
        return AppColors.agentMarcus;
      default:
        return AppColors.prismPurple;
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
        border:
            Border.all(color: _color.withOpacity(0.3), width: 0.5),
      ),
      child: Center(
        child: Text(
          '.${ext.toUpperCase()}',
          style: TextStyle(
              color: _color,
              fontSize: 9,
              fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final AnalysisStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case AnalysisStatus.complete:
        color = AppColors.success;
        break;
      case AnalysisStatus.failed:
        color = AppColors.error;
        break;
      case AnalysisStatus.running:
      case AnalysisStatus.parsing:
      case AnalysisStatus.synthesizing:
        color = AppColors.warning;
        break;
      default:
        color = AppColors.textTertiaryDark;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.label,
        style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}

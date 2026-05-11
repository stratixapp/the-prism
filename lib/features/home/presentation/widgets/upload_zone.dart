import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';

class UploadZone extends StatefulWidget {
  final void Function(File file) onFileSelected;

  const UploadZone({super.key, required this.onFileSelected});

  @override
  State<UploadZone> createState() => _UploadZoneState();
}

class _UploadZoneState extends State<UploadZone> {
  bool _isDragging = false;
  bool _isPickingFile = false;

  Future<void> _pickFile() async {
    if (_isPickingFile) return;
    setState(() => _isPickingFile = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path == null) return;

        final file = File(path);
        final sizeBytes = await file.length();

        // Validate size
        if (sizeBytes > AppConstants.maxFileSizeBytes) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'File too large. Maximum ${AppConstants.maxFileSizeMb}MB allowed.'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }

        widget.onFileSelected(file);
      }
    } finally {
      if (mounted) setState(() => _isPickingFile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _pickFile,
      child: AnimatedContainer(
        duration: AppConstants.animNormal,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: _isDragging
              ? AppColors.prismPurpleDark.withOpacity(0.15)
              : AppColors.bgDarkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isDragging
                ? AppColors.prismPurple
                : AppColors.borderDark,
            width: _isDragging ? 1.5 : 0.5,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Icon ───────────────────────────────────────────────────
            AnimatedContainer(
              duration: AppConstants.animFast,
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _isDragging
                    ? AppColors.prismPurpleDark
                    : AppColors.bgDarkElevated,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPickingFile
                    ? Icons.hourglass_top_outlined
                    : Icons.cloud_upload_outlined,
                color: _isDragging
                    ? AppColors.prismPurple
                    : AppColors.textSecondaryDark,
                size: 26,
              ),
            ),

            const SizedBox(height: 14),

            // ── Label ──────────────────────────────────────────────────
            Text(
              _isPickingFile
                  ? 'Opening file picker...'
                  : 'Drop your file here',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimaryDark,
                  ),
            ),

            const SizedBox(height: 4),

            Text(
              'or tap to browse · Max ${AppConstants.maxFileSizeMb}MB',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiaryDark,
                  ),
            ),

            const SizedBox(height: 16),

            // ── File type chips ────────────────────────────────────────
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: const [
                'PDF', 'ZIP', 'APK', 'DOCX', 'XLSX', 'CSV', 'TXT', 'JSON', 'CODE'
              ].map((type) => _FileTypeBadge(label: type)).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileTypeBadge extends StatelessWidget {
  final String label;
  const _FileTypeBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgDark,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderDark, width: 0.5),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textTertiaryDark,
              fontSize: 10,
            ),
      ),
    );
  }
}

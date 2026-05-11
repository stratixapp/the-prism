// lib/features/export/presentation/providers/export_provider.dart
// Phase 17 — Export state management

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../shared/models/analysis_model.dart';
import '../../data/pdf_export_service.dart';

part 'export_provider.g.dart';

@riverpod
PdfExportService pdfExportService(PdfExportServiceRef ref) {
  return PdfExportService();
}

enum ExportAction { share, print, save }

@riverpod
class ExportNotifier extends _$ExportNotifier {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> exportAnalysis(
    AnalysisModel analysis,
    ExportAction action,
  ) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(pdfExportServiceProvider);
      switch (action) {
        case ExportAction.share:
          await service.shareReport(analysis);
          break;
        case ExportAction.print:
          await service.printReport(analysis);
          break;
        case ExportAction.save:
          await service.saveToFile(analysis);
          break;
      }
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

// =========================================================
// home_provider.dart
// =========================================================
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/models/analysis_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

part 'home_provider.g.dart';

// Recent analyses stream
@riverpod
Stream<List<AnalysisModel>> recentAnalyses(RecentAnalysesRef ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();

  return ref
      .watch(firestoreProvider)
      .collection(AppConstants.colAnalyses)
      .where('userId', isEqualTo: user.uid)
      .orderBy('createdAt', descending: true)
      .limit(AppConstants.historyPageSize)
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => AnalysisModel.fromFirestore(d)).toList());
}

// Home notifier — handles starting an analysis
@riverpod
class HomeNotifier extends _$HomeNotifier {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> startAnalysis(File file, BuildContext context) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    // Create analysis document in Firestore
    final docRef = ref
        .read(firestoreProvider)
        .collection(AppConstants.colAnalyses)
        .doc();

    final analysis = AnalysisModel(
      id: docRef.id,
      userId: user.uid,
      fileMetadata: FileMetadata(
        name: file.path.split('/').last,
        extension: file.path.split('.').last.toLowerCase(),
        sizeBytes: file.lengthSync(),
        mimeType: 'application/octet-stream',
      ),
      aiProvider: AppConstants.aiProviderClaude,
      status: AnalysisStatus.pending,
      agentOutputs: [],
      createdAt: DateTime.now(),
    );

    await docRef.set(analysis.toMap());

    if (context.mounted) {
      context.push(
        AppRoutes.analysisPath(docRef.id),
        extra: {
          'file': file,
          'focusQuestion': '',
          'aiProvider': AppConstants.aiProviderClaude,
        },
      );
    }
  }
}

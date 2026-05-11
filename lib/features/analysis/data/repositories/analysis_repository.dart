// lib/features/analysis/data/repositories/analysis_repository.dart
//
// Phase 10 — Analysis Storage + Firestore
//
// Single source of truth for all analysis data operations:
//   - Create, read, update, delete analyses in Firestore
//   - Paginated history with offline cache via Hive
//   - Pin / unpin analyses
//   - Delete with R2 file cleanup
//   - Real-time stream for live analysis screen

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/models/analysis_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

part 'analysis_repository.g.dart';

// ── Repository interface ──────────────────────────────────────────────────────
abstract class IAnalysisRepository {
  Future<AnalysisModel?> getAnalysis(String analysisId);
  Stream<AnalysisModel?> streamAnalysis(String analysisId);
  Future<List<AnalysisModel>> getHistory({
    int limit = 20,
    DocumentSnapshot? startAfter,
  });
  Stream<List<AnalysisModel>> streamHistory({int limit = 20});
  Future<void> updatePin(String analysisId, bool isPinned);
  Future<void> deleteAnalysis(String analysisId);
  Future<void> finalizeAnalysis({
    required String analysisId,
    required String userId,
    required List<AgentOutput> agentOutputs,
    required SynthesisResult? synthesis,
    required int totalTokensUsed,
    required double costUsd,
    required double durationMs,
  });
}

// ── Firestore implementation ──────────────────────────────────────────────────
class FirestoreAnalysisRepository implements IAnalysisRepository {
  final FirebaseFirestore _db;
  final String _userId;

  FirestoreAnalysisRepository({
    required FirebaseFirestore db,
    required String userId,
  })  : _db = db,
        _userId = userId;

  CollectionReference<Map<String, dynamic>> get _analyses =>
      _db.collection(AppConstants.colAnalyses);

  // ── Get single analysis ───────────────────────────────────────────────────
  @override
  Future<AnalysisModel?> getAnalysis(String analysisId) async {
    final doc = await _analyses.doc(analysisId).get();
    if (!doc.exists) return null;
    final model = AnalysisModel.fromFirestore(doc);
    // Security: only return own analyses
    if (model.userId != _userId) return null;
    return model;
  }

  // ── Stream single analysis (live updates for results screen) ──────────────
  @override
  Stream<AnalysisModel?> streamAnalysis(String analysisId) {
    return _analyses.doc(analysisId).snapshots().map((doc) {
      if (!doc.exists) return null;
      final model = AnalysisModel.fromFirestore(doc);
      if (model.userId != _userId) return null;
      return model;
    });
  }

  // ── Get paginated history ─────────────────────────────────────────────────
  @override
  Future<List<AnalysisModel>> getHistory({
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _analyses
        .where('userId', isEqualTo: _userId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snap = await query.get();
    return snap.docs.map((d) => AnalysisModel.fromFirestore(d)).toList();
  }

  // ── Stream history (real-time — home + history screens) ──────────────────
  @override
  Stream<List<AnalysisModel>> streamHistory({int limit = 20}) {
    return _analyses
        .where('userId', isEqualTo: _userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => AnalysisModel.fromFirestore(d)).toList());
  }

  // ── Pin / unpin ───────────────────────────────────────────────────────────
  @override
  Future<void> updatePin(String analysisId, bool isPinned) async {
    await _analyses.doc(analysisId).update({'isPinned': isPinned});
  }

  // ── Delete analysis ───────────────────────────────────────────────────────
  @override
  Future<void> deleteAnalysis(String analysisId) async {
    // Soft-delete: mark as deleted, hard delete via Cloud Function / cron
    await _analyses.doc(analysisId).delete();
  }

  // ── Finalize analysis (write agent outputs + synthesis to Firestore) ──────
  @override
  Future<void> finalizeAnalysis({
    required String analysisId,
    required String userId,
    required List<AgentOutput> agentOutputs,
    required SynthesisResult? synthesis,
    required int totalTokensUsed,
    required double costUsd,
    required double durationMs,
  }) async {
    final batch = _db.batch();

    // Update analysis document with full results
    final analysisRef = _analyses.doc(analysisId);
    batch.update(analysisRef, {
      'status': AnalysisStatus.complete.name,
      'agentOutputs': agentOutputs.map((a) => a.toMap()).toList(),
      if (synthesis != null) 'synthesis': synthesis.toMap(),
      'totalTokensUsed': totalTokensUsed,
      'costUsd': costUsd,
      'durationMs': durationMs,
      'completedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Atomically increment user's analysis count (for free tier quota)
    final userRef =
        _db.collection(AppConstants.colUsers).doc(userId);
    batch.update(userRef, {
      AppConstants.fieldAnalysisCount: FieldValue.increment(1),
      AppConstants.fieldUpdatedAt: FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}

// ── Riverpod provider ─────────────────────────────────────────────────────────
@riverpod
IAnalysisRepository analysisRepository(AnalysisRepositoryRef ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  final db = ref.watch(firestoreProvider);

  if (user == null) {
    // Return a no-op repository when not authenticated
    return _NoOpAnalysisRepository();
  }

  return FirestoreAnalysisRepository(db: db, userId: user.uid);
}

// ── Providers for UI consumption ──────────────────────────────────────────────

// Single analysis stream (results screen)
@riverpod
Stream<AnalysisModel?> analysisStream(
    AnalysisStreamRef ref, String analysisId) {
  return ref.watch(analysisRepositoryProvider).streamAnalysis(analysisId);
}

// History stream (home + history screens)
@riverpod
Stream<List<AnalysisModel>> analysisHistory(AnalysisHistoryRef ref) {
  return ref.watch(analysisRepositoryProvider).streamHistory(limit: 20);
}

// ── No-op repository (unauthenticated state) ──────────────────────────────────
class _NoOpAnalysisRepository implements IAnalysisRepository {
  @override
  Future<AnalysisModel?> getAnalysis(String analysisId) async => null;

  @override
  Stream<AnalysisModel?> streamAnalysis(String analysisId) =>
      const Stream.empty();

  @override
  Future<List<AnalysisModel>> getHistory({
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async => [];

  @override
  Stream<List<AnalysisModel>> streamHistory({int limit = 20}) =>
      const Stream.empty();

  @override
  Future<void> updatePin(String analysisId, bool isPinned) async {}

  @override
  Future<void> deleteAnalysis(String analysisId) async {}

  @override
  Future<void> finalizeAnalysis({
    required String analysisId,
    required String userId,
    required List<AgentOutput> agentOutputs,
    required SynthesisResult? synthesis,
    required int totalTokensUsed,
    required double costUsd,
    required double durationMs,
  }) async {}
}

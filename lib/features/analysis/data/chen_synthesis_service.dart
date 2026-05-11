// lib/features/analysis/data/chen_synthesis_service.dart
//
// Phase 9 — Chen Synthesis Engine
//
// Chen's raw output arrives as plain text with three bold sections.
// This service:
//   1. Parses Chen's output into structured SynthesisResult
//   2. Writes the full completed analysis to Firestore
//   3. Updates the user's analysis count for quota tracking
//   4. Extracts confidence score heuristically

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/models/analysis_model.dart';

class ChenSynthesisService {
  final FirebaseFirestore db;

  const ChenSynthesisService({required this.db});

  // ── Parse Chen's raw text into SynthesisResult ────────────────────────────
  SynthesisResult? parseChenOutput(String rawText) {
    if (rawText.isEmpty) return null;

    // Chen's format:
    //   **#1 INSIGHT**
    //   <text>
    //   **#1 GAP**
    //   <text>
    //   **#1 OPPORTUNITY**
    //   <text>

    final insightMatch = RegExp(
      r'\*{0,2}#1\s+INSIGHT\*{0,2}[:\s]*([\s\S]*?)(?=\*{0,2}#1\s+GAP|\*{0,2}#1\s+OPPORTUNITY|$)',
      caseSensitive: false,
    ).firstMatch(rawText);

    final gapMatch = RegExp(
      r'\*{0,2}#1\s+GAP\*{0,2}[:\s]*([\s\S]*?)(?=\*{0,2}#1\s+OPPORTUNITY|$)',
      caseSensitive: false,
    ).firstMatch(rawText);

    final opportunityMatch = RegExp(
      r'\*{0,2}#1\s+OPPORTUNITY\*{0,2}[:\s]*([\s\S]*?)$',
      caseSensitive: false,
    ).firstMatch(rawText);

    final insight = insightMatch?.group(1)?.trim() ?? '';
    final gap = gapMatch?.group(1)?.trim() ?? '';
    final opportunity = opportunityMatch?.group(1)?.trim() ?? '';

    // Fallback: if parsing failed, use the full text as insight
    if (insight.isEmpty && gap.isEmpty && opportunity.isEmpty) {
      return SynthesisResult(
        topInsight: rawText.trim(),
        topGap: '',
        topOpportunity: '',
        confidenceScore: 0.7,
        fullText: rawText,
      );
    }

    // Heuristic confidence score based on output completeness
    double confidence = 0.0;
    if (insight.length > 50) confidence += 0.35;
    if (gap.length > 50) confidence += 0.35;
    if (opportunity.length > 50) confidence += 0.30;

    return SynthesisResult(
      topInsight: insight,
      topGap: gap,
      topOpportunity: opportunity,
      confidenceScore: confidence.clamp(0.5, 1.0),
      fullText: rawText,
    );
  }

  // ── Write completed analysis to Firestore ─────────────────────────────────
  Future<void> finalizeAnalysis({
    required String analysisId,
    required String userId,
    required List<AgentOutput> agentOutputs,
    required SynthesisResult? synthesis,
    required int totalTokensUsed,
    required double costUsd,
    required double durationMs,
  }) async {
    final batch = db.batch();

    // Update analysis document
    final analysisRef =
        db.collection(AppConstants.colAnalyses).doc(analysisId);

    batch.update(analysisRef, {
      'status': AnalysisStatus.complete.name,
      'agentOutputs': agentOutputs.map((a) => a.toMap()).toList(),
      if (synthesis != null) 'synthesis': synthesis.toMap(),
      'totalTokensUsed': totalTokensUsed,
      'costUsd': costUsd,
      'durationMs': durationMs,
      'completedAt': FieldValue.serverTimestamp(),
    });

    // Increment user's analysis count
    final userRef = db.collection(AppConstants.colUsers).doc(userId);
    batch.update(userRef, {
      AppConstants.fieldAnalysisCount: FieldValue.increment(1),
      AppConstants.fieldUpdatedAt: FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ── Mark analysis as failed ───────────────────────────────────────────────
  Future<void> markFailed({
    required String analysisId,
    required String errorMessage,
  }) async {
    await db.collection(AppConstants.colAnalyses).doc(analysisId).update({
      'status': AnalysisStatus.failed.name,
      'errorMessage': errorMessage,
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Fetch a completed analysis ────────────────────────────────────────────
  Future<AnalysisModel?> fetchAnalysis(String analysisId) async {
    final doc = await db
        .collection(AppConstants.colAnalyses)
        .doc(analysisId)
        .get();

    if (!doc.exists) return null;
    return AnalysisModel.fromFirestore(doc);
  }

  // ── Stream real-time analysis updates ────────────────────────────────────
  Stream<AnalysisModel?> streamAnalysis(String analysisId) {
    return db
        .collection(AppConstants.colAnalyses)
        .doc(analysisId)
        .snapshots()
        .map((doc) => doc.exists ? AnalysisModel.fromFirestore(doc) : null);
  }
}

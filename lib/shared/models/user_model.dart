import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../../core/constants/app_constants.dart';

class PrismUser extends Equatable {
  final String uid;
  final String email;
  final String displayName;
  final String plan;
  final int analysisCount;
  final DateTime? analysisCountResetAt;
  final String industry;
  final String preferredAiProvider;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PrismUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.plan,
    required this.analysisCount,
    this.analysisCountResetAt,
    required this.industry,
    required this.preferredAiProvider,
    this.createdAt,
    this.updatedAt,
  });

  // ── Getters ───────────────────────────────────────────────────────────
  bool get isPro => plan == AppConstants.planPro || plan == AppConstants.planTeam;
  bool get isTeam => plan == AppConstants.planTeam;
  bool get isFree => plan == AppConstants.planFree;

  int get allowedAgents =>
      isPro ? AppConstants.proAgentsPerAnalysis : AppConstants.freeAgentsPerAnalysis;

  bool get hasAnalysesRemaining =>
      isPro || analysisCount < AppConstants.freeAnalysesPerMonth;

  int get remainingFreeAnalyses =>
      (AppConstants.freeAnalysesPerMonth - analysisCount).clamp(0, 999);

  // ── Factory: Firestore ────────────────────────────────────────────────
  factory PrismUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PrismUser(
      uid: data[AppConstants.fieldUid] as String? ?? doc.id,
      email: data[AppConstants.fieldEmail] as String? ?? '',
      displayName: data[AppConstants.fieldDisplayName] as String? ?? 'Prism User',
      plan: data[AppConstants.fieldPlan] as String? ?? AppConstants.planFree,
      analysisCount: data[AppConstants.fieldAnalysisCount] as int? ?? 0,
      analysisCountResetAt:
          (data[AppConstants.fieldAnalysisCountResetAt] as Timestamp?)?.toDate(),
      industry: data[AppConstants.fieldIndustry] as String? ?? 'general',
      preferredAiProvider:
          data[AppConstants.fieldPreferredAiProvider] as String? ??
              AppConstants.aiProviderClaude,
      createdAt: (data[AppConstants.fieldCreatedAt] as Timestamp?)?.toDate(),
      updatedAt: (data[AppConstants.fieldUpdatedAt] as Timestamp?)?.toDate(),
    );
  }

  // ── To Firestore map ──────────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
        AppConstants.fieldUid: uid,
        AppConstants.fieldEmail: email,
        AppConstants.fieldDisplayName: displayName,
        AppConstants.fieldPlan: plan,
        AppConstants.fieldAnalysisCount: analysisCount,
        AppConstants.fieldIndustry: industry,
        AppConstants.fieldPreferredAiProvider: preferredAiProvider,
        AppConstants.fieldUpdatedAt: FieldValue.serverTimestamp(),
      };

  // ── CopyWith ──────────────────────────────────────────────────────────
  PrismUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? plan,
    int? analysisCount,
    DateTime? analysisCountResetAt,
    String? industry,
    String? preferredAiProvider,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PrismUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      plan: plan ?? this.plan,
      analysisCount: analysisCount ?? this.analysisCount,
      analysisCountResetAt: analysisCountResetAt ?? this.analysisCountResetAt,
      industry: industry ?? this.industry,
      preferredAiProvider: preferredAiProvider ?? this.preferredAiProvider,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        uid, email, displayName, plan,
        analysisCount, industry, preferredAiProvider,
      ];
}

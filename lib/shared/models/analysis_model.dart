import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../../core/constants/app_constants.dart';

// ── Analysis Status ───────────────────────────────────────────────────────────
enum AnalysisStatus { pending, parsing, running, synthesizing, complete, failed }

extension AnalysisStatusX on AnalysisStatus {
  String get label {
    switch (this) {
      case AnalysisStatus.pending: return 'Pending';
      case AnalysisStatus.parsing: return 'Parsing file...';
      case AnalysisStatus.running: return 'Agents running...';
      case AnalysisStatus.synthesizing: return 'Synthesizing...';
      case AnalysisStatus.complete: return 'Complete';
      case AnalysisStatus.failed: return 'Failed';
    }
  }

  bool get isTerminal =>
      this == AnalysisStatus.complete || this == AnalysisStatus.failed;
}

// ── Agent Output ──────────────────────────────────────────────────────────────
class AgentOutput extends Equatable {
  final String agentId;
  final String content;
  final bool isComplete;
  final int? tokensUsed;
  final double? durationMs;
  final String? error;

  const AgentOutput({
    required this.agentId,
    required this.content,
    this.isComplete = false,
    this.tokensUsed,
    this.durationMs,
    this.error,
  });

  bool get hasError => error != null;

  factory AgentOutput.fromMap(Map<String, dynamic> map) {
    return AgentOutput(
      agentId: map['agentId'] as String,
      content: map['content'] as String? ?? '',
      isComplete: map['isComplete'] as bool? ?? false,
      tokensUsed: map['tokensUsed'] as int?,
      durationMs: (map['durationMs'] as num?)?.toDouble(),
      error: map['error'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'agentId': agentId,
        'content': content,
        'isComplete': isComplete,
        if (tokensUsed != null) 'tokensUsed': tokensUsed,
        if (durationMs != null) 'durationMs': durationMs,
        if (error != null) 'error': error,
      };

  AgentOutput copyWith({
    String? content,
    bool? isComplete,
    int? tokensUsed,
    double? durationMs,
    String? error,
  }) {
    return AgentOutput(
      agentId: agentId,
      content: content ?? this.content,
      isComplete: isComplete ?? this.isComplete,
      tokensUsed: tokensUsed ?? this.tokensUsed,
      durationMs: durationMs ?? this.durationMs,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [agentId, content, isComplete];
}

// ── Synthesis (Chen Output) ───────────────────────────────────────────────────
class SynthesisResult extends Equatable {
  final String topInsight;
  final String topGap;
  final String topOpportunity;
  final double confidenceScore; // 0.0 - 1.0
  final String fullText;

  const SynthesisResult({
    required this.topInsight,
    required this.topGap,
    required this.topOpportunity,
    required this.confidenceScore,
    required this.fullText,
  });

  factory SynthesisResult.fromMap(Map<String, dynamic> map) {
    return SynthesisResult(
      topInsight: map['topInsight'] as String? ?? '',
      topGap: map['topGap'] as String? ?? '',
      topOpportunity: map['topOpportunity'] as String? ?? '',
      confidenceScore: (map['confidenceScore'] as num?)?.toDouble() ?? 0.8,
      fullText: map['fullText'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'topInsight': topInsight,
        'topGap': topGap,
        'topOpportunity': topOpportunity,
        'confidenceScore': confidenceScore,
        'fullText': fullText,
      };

  @override
  List<Object?> get props => [topInsight, topGap, topOpportunity];
}

// ── File Metadata ─────────────────────────────────────────────────────────────
class FileMetadata extends Equatable {
  final String name;
  final String extension;
  final int sizeBytes;
  final String mimeType;
  final String? r2Key; // Cloudflare R2 storage key

  const FileMetadata({
    required this.name,
    required this.extension,
    required this.sizeBytes,
    required this.mimeType,
    this.r2Key,
  });

  String get sizeLabel {
    if (sizeBytes < 1024) return '${sizeBytes}B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)}KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  factory FileMetadata.fromMap(Map<String, dynamic> map) {
    return FileMetadata(
      name: map['name'] as String,
      extension: map['extension'] as String,
      sizeBytes: map['sizeBytes'] as int,
      mimeType: map['mimeType'] as String? ?? 'application/octet-stream',
      r2Key: map['r2Key'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'extension': extension,
        'sizeBytes': sizeBytes,
        'mimeType': mimeType,
        if (r2Key != null) 'r2Key': r2Key,
      };

  @override
  List<Object?> get props => [name, extension, sizeBytes];
}

// ── Main Analysis Model ───────────────────────────────────────────────────────
class AnalysisModel extends Equatable {
  final String id;
  final String userId;
  final FileMetadata fileMetadata;
  final String? focusQuestion;
  final String aiProvider;
  final AnalysisStatus status;
  final List<AgentOutput> agentOutputs;
  final SynthesisResult? synthesis;
  final int totalTokensUsed;
  final double? costUsd;
  final double? durationMs;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;
  final bool isPinned;

  const AnalysisModel({
    required this.id,
    required this.userId,
    required this.fileMetadata,
    this.focusQuestion,
    required this.aiProvider,
    required this.status,
    required this.agentOutputs,
    this.synthesis,
    this.totalTokensUsed = 0,
    this.costUsd,
    this.durationMs,
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
    this.isPinned = false,
  });

  // ── Getters ───────────────────────────────────────────────────────────
  bool get isComplete => status == AnalysisStatus.complete;
  bool get isFailed => status == AnalysisStatus.failed;
  bool get isRunning =>
      status == AnalysisStatus.running ||
      status == AnalysisStatus.parsing ||
      status == AnalysisStatus.synthesizing;

  int get completedAgentCount =>
      agentOutputs.where((a) => a.isComplete).length;

  double get progressPercent =>
      agentOutputs.isEmpty ? 0 : completedAgentCount / agentOutputs.length;

  AgentOutput? outputFor(String agentId) {
    try {
      return agentOutputs.firstWhere((a) => a.agentId == agentId);
    } catch (_) {
      return null;
    }
  }

  // ── Firestore ─────────────────────────────────────────────────────────
  factory AnalysisModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AnalysisModel(
      id: doc.id,
      userId: data['userId'] as String,
      fileMetadata: FileMetadata.fromMap(
          data['fileMetadata'] as Map<String, dynamic>),
      focusQuestion: data['focusQuestion'] as String?,
      aiProvider: data['aiProvider'] as String? ?? AppConstants.aiProviderClaude,
      status: AnalysisStatus.values.firstWhere(
        (s) => s.name == (data['status'] as String? ?? 'pending'),
        orElse: () => AnalysisStatus.pending,
      ),
      agentOutputs: (data['agentOutputs'] as List<dynamic>? ?? [])
          .map((e) => AgentOutput.fromMap(e as Map<String, dynamic>))
          .toList(),
      synthesis: data['synthesis'] != null
          ? SynthesisResult.fromMap(data['synthesis'] as Map<String, dynamic>)
          : null,
      totalTokensUsed: data['totalTokensUsed'] as int? ?? 0,
      costUsd: (data['costUsd'] as num?)?.toDouble(),
      durationMs: (data['durationMs'] as num?)?.toDouble(),
      errorMessage: data['errorMessage'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      isPinned: data['isPinned'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'fileMetadata': fileMetadata.toMap(),
        if (focusQuestion != null) 'focusQuestion': focusQuestion,
        'aiProvider': aiProvider,
        'status': status.name,
        'agentOutputs': agentOutputs.map((a) => a.toMap()).toList(),
        if (synthesis != null) 'synthesis': synthesis!.toMap(),
        'totalTokensUsed': totalTokensUsed,
        if (costUsd != null) 'costUsd': costUsd,
        if (durationMs != null) 'durationMs': durationMs,
        if (errorMessage != null) 'errorMessage': errorMessage,
        'createdAt': Timestamp.fromDate(createdAt),
        if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
        'isPinned': isPinned,
      };

  AnalysisModel copyWith({
    AnalysisStatus? status,
    List<AgentOutput>? agentOutputs,
    SynthesisResult? synthesis,
    int? totalTokensUsed,
    double? costUsd,
    double? durationMs,
    String? errorMessage,
    DateTime? completedAt,
    bool? isPinned,
  }) {
    return AnalysisModel(
      id: id,
      userId: userId,
      fileMetadata: fileMetadata,
      focusQuestion: focusQuestion,
      aiProvider: aiProvider,
      status: status ?? this.status,
      agentOutputs: agentOutputs ?? this.agentOutputs,
      synthesis: synthesis ?? this.synthesis,
      totalTokensUsed: totalTokensUsed ?? this.totalTokensUsed,
      costUsd: costUsd ?? this.costUsd,
      durationMs: durationMs ?? this.durationMs,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  @override
  List<Object?> get props => [id, userId, status, agentOutputs.length];
}

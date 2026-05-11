// lib/features/analysis/presentation/providers/analysis_provider.dart
//
// Manages the full lifecycle of a live analysis:
//   1. Upload file → R2
//   2. Create Firestore document
//   3. Open SSE stream to Cloudflare Worker
//   4. Route incoming events to per-agent state
//   5. Write completed outputs back to Firestore
//   6. Handle errors, retries, cancellation

import 'dart:io';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:dio/dio.dart';
import 'package:mime/mime.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_errors.dart';
import '../../../../shared/models/analysis_model.dart';
import '../../../../shared/models/agent_model.dart';
import '../../../../shared/services/sse_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/chen_synthesis_service.dart';

part 'analysis_provider.g.dart';

// ── Per-Agent Stream State ────────────────────────────────────────────────────
class AgentStreamState {
  final String agentId;
  final String accumulatedText;
  final bool isRunning;
  final bool isComplete;
  final bool hasError;
  final String? errorMessage;
  final int tokensUsed;
  final double durationMs;

  const AgentStreamState({
    required this.agentId,
    this.accumulatedText = '',
    this.isRunning = false,
    this.isComplete = false,
    this.hasError = false,
    this.errorMessage,
    this.tokensUsed = 0,
    this.durationMs = 0,
  });

  AgentStreamState copyWith({
    String? accumulatedText,
    bool? isRunning,
    bool? isComplete,
    bool? hasError,
    String? errorMessage,
    int? tokensUsed,
    double? durationMs,
  }) =>
      AgentStreamState(
        agentId: agentId,
        accumulatedText: accumulatedText ?? this.accumulatedText,
        isRunning: isRunning ?? this.isRunning,
        isComplete: isComplete ?? this.isComplete,
        hasError: hasError ?? this.hasError,
        errorMessage: errorMessage ?? this.errorMessage,
        tokensUsed: tokensUsed ?? this.tokensUsed,
        durationMs: durationMs ?? this.durationMs,
      );
}

// ── Analysis Session State ────────────────────────────────────────────────────
class AnalysisSessionState {
  final String analysisId;
  final AnalysisStatus status;
  final Map<String, AgentStreamState> agentStates;
  final int totalTokens;
  final double estimatedCostUsd;
  final int completedAgentCount;
  final int totalAgentCount;
  final String? errorMessage;
  final bool isCancelled;

  const AnalysisSessionState({
    required this.analysisId,
    required this.status,
    required this.agentStates,
    this.totalTokens = 0,
    this.estimatedCostUsd = 0,
    this.completedAgentCount = 0,
    required this.totalAgentCount,
    this.errorMessage,
    this.isCancelled = false,
  });

  double get progressFraction =>
      totalAgentCount == 0 ? 0 : completedAgentCount / totalAgentCount;

  bool get isTerminal =>
      status == AnalysisStatus.complete ||
      status == AnalysisStatus.failed ||
      isCancelled;

  AgentStreamState? agentState(String agentId) => agentStates[agentId];

  AnalysisSessionState copyWith({
    AnalysisStatus? status,
    Map<String, AgentStreamState>? agentStates,
    int? totalTokens,
    double? estimatedCostUsd,
    int? completedAgentCount,
    String? errorMessage,
    bool? isCancelled,
  }) =>
      AnalysisSessionState(
        analysisId: analysisId,
        status: status ?? this.status,
        agentStates: agentStates ?? this.agentStates,
        totalTokens: totalTokens ?? this.totalTokens,
        estimatedCostUsd: estimatedCostUsd ?? this.estimatedCostUsd,
        completedAgentCount: completedAgentCount ?? this.completedAgentCount,
        totalAgentCount: totalAgentCount,
        errorMessage: errorMessage ?? this.errorMessage,
        isCancelled: isCancelled ?? this.isCancelled,
      );
}

// ── Analysis Notifier ─────────────────────────────────────────────────────────
@riverpod
class AnalysisNotifier extends _$AnalysisNotifier {
  StreamSubscription<SseEvent>? _sseSubscription;
  final _uuid = const Uuid();

  @override
  AsyncValue<AnalysisSessionState?> build() => const AsyncValue.data(null);

  FirebaseAuth get _auth => ref.read(firebaseAuthProvider);
  FirebaseFirestore get _db => ref.read(firestoreProvider);

  // ── Step 1: Upload file → R2 ──────────────────────────────────────────────
  Future<String?> _uploadFile(File file, String userId) async {
    final idToken = await _auth.currentUser?.getIdToken();
    if (idToken == null) throw const AuthFailure(message: 'Not authenticated');

    final fileName = file.path.split('/').last;
    final mimeType =
        lookupMimeType(file.path) ?? 'application/octet-stream';

    final dio = Dio();
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: fileName,
        contentType: DioMediaType.parse(mimeType),
      ),
    });

    try {
      final response = await dio.post(
        '${AppConstants.apiBaseUrl}/api/upload',
        data: formData,
        options: Options(
          headers: {'Authorization': 'Bearer $idToken'},
          receiveTimeout: const Duration(minutes: 2),
          sendTimeout: const Duration(minutes: 2),
        ),
      );

      return response.data['r2Key'] as String?;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 413) throw const FileTooLargeFailure();
      if (statusCode == 401) throw const AuthFailure(message: 'Session expired');
      throw FileUploadFailure(
          message: e.response?.data?['message'] as String? ?? 'Upload failed');
    }
  }

  // ── Step 2: Start full analysis pipeline ──────────────────────────────────
  Future<void> startAnalysis({
    required File file,
    required String focusQuestion,
    required String aiProvider,
    required List<String> agentIds,
    required bool isPro,
  }) async {
    state = const AsyncValue.loading();

    try {
      final user = _auth.currentUser;
      if (user == null) throw const AuthFailure(message: 'Not authenticated');

      final idToken = await user.getIdToken();
      if (idToken == null) throw const AuthFailure(message: 'Token error');

      final fileName = file.path.split('/').last;
      final ext = fileName.contains('.')
          ? fileName.split('.').last.toLowerCase()
          : 'bin';
      final mimeType =
          lookupMimeType(file.path) ?? 'application/octet-stream';
      final fileSize = await file.length();

      // Validate file size
      if (fileSize > AppConstants.maxFileSizeBytes) {
        throw const FileTooLargeFailure();
      }

      // ── Upload file to R2 ──────────────────────────────────────────
      final r2Key = await _uploadFile(file, user.uid);
      if (r2Key == null) throw const FileUploadFailure();

      // ── Create Firestore analysis doc ──────────────────────────────
      final analysisId = _uuid.v4();
      final docRef = _db
          .collection(AppConstants.colAnalyses)
          .doc(analysisId);

      final agentOutputs = agentIds
          .map((id) => AgentOutput(agentId: id, content: ''))
          .toList();

      final analysis = AnalysisModel(
        id: analysisId,
        userId: user.uid,
        fileMetadata: FileMetadata(
          name: fileName,
          extension: ext,
          sizeBytes: fileSize,
          mimeType: mimeType,
          r2Key: r2Key,
        ),
        focusQuestion: focusQuestion.isNotEmpty ? focusQuestion : null,
        aiProvider: aiProvider,
        status: AnalysisStatus.parsing,
        agentOutputs: agentOutputs,
        createdAt: DateTime.now(),
      );

      await docRef.set(analysis.toMap());

      // ── Initialize session state ───────────────────────────────────
      final initialAgentStates = Map.fromEntries(
        agentIds.map((id) => MapEntry(id, AgentStreamState(agentId: id))),
      );

      state = AsyncValue.data(AnalysisSessionState(
        analysisId: analysisId,
        status: AnalysisStatus.parsing,
        agentStates: initialAgentStates,
        totalAgentCount: agentIds.length,
      ));

      // ── Open SSE stream ────────────────────────────────────────────
      final sseService = SseService(
        baseUrl: AppConstants.apiBaseUrl,
        authToken: idToken,
      );

      final stream = sseService.streamAnalysis(
        analysisId: analysisId,
        r2Key: r2Key,
        fileName: fileName,
        fileExtension: ext,
        mimeType: mimeType,
        focusQuestion: focusQuestion.isNotEmpty ? focusQuestion : null,
        aiProvider: aiProvider,
        agentIds: agentIds,
      );

      _sseSubscription = stream.listen(
        _handleSseEvent,
        onError: _handleSseError,
        onDone: () => _handleStreamDone(analysisId, docRef),
        cancelOnError: false,
      );
    } on Failure catch (f) {
      state = AsyncValue.error(f, StackTrace.current);
    } catch (e, st) {
      state = AsyncValue.error(
        UnknownFailure(message: e.toString()),
        st,
      );
    }
  }

  // ── SSE Event Router ──────────────────────────────────────────────────────
  void _handleSseEvent(SseEvent event) {
    final current = state.valueOrNull;
    if (current == null || current.isCancelled) return;

    switch (event.type) {
      case 'status':
        final status = event.asStatus();
        if (status == null) return;
        _updateStatus(_mapStatus(status.status));
        break;

      case 'agent_start':
        final e = event.asAgentStart();
        if (e == null) return;
        _updateAgent(e.agentId, (s) => s.copyWith(isRunning: true));
        break;

      case 'agent_token':
        final e = event.asAgentToken();
        if (e == null) return;
        // Strip _gpt suffix for dual-engine display
        final agentId = e.agentId.replaceAll('_gpt', '');
        _updateAgent(
          agentId,
          (s) => s.copyWith(
            accumulatedText: s.accumulatedText + e.token,
            isRunning: true,
          ),
        );
        break;

      case 'agent_complete':
        final e = event.asAgentComplete();
        if (e == null) return;
        final agentId = e.agentId.replaceAll('_gpt', '');
        _updateAgent(
          agentId,
          (s) => s.copyWith(
            accumulatedText: e.fullText,
            isRunning: false,
            isComplete: true,
            tokensUsed: e.tokensUsed,
            durationMs: e.durationMs,
          ),
        );
        _incrementCompleted();
        break;

      case 'agent_error':
        final agentId =
            event.data['agentId'] as String? ?? 'unknown';
        final error =
            event.data['error'] as String? ?? 'Agent failed';
        _updateAgent(
          agentId,
          (s) => s.copyWith(
            isRunning: false,
            isComplete: true,
            hasError: true,
            errorMessage: error,
          ),
        );
        _incrementCompleted();
        break;

      case 'cost_update':
        final e = event.asCostUpdate();
        if (e == null) return;
        state = AsyncValue.data(
          current.copyWith(
            totalTokens: e.totalTokens,
            estimatedCostUsd: e.estimatedCostUsd,
          ),
        );
        break;
    }
  }

  void _handleSseError(Object error) {
    if (error is SseException && error.isQuotaExceeded) {
      state = AsyncValue.error(
        const QuotaExceededFailure(),
        StackTrace.current,
      );
    } else {
      state = AsyncValue.error(
        AnalysisFailure(message: error.toString()),
        StackTrace.current,
      );
    }
  }

  Future<void> _handleStreamDone(
      String analysisId, DocumentReference docRef) async {
    final current = state.valueOrNull;
    if (current == null) return;

    // Build final agent output list from stream state
    final agentOutputs = current.agentStates.values.map((s) {
      return AgentOutput(
        agentId: s.agentId,
        content: s.accumulatedText,
        isComplete: s.isComplete,
        tokensUsed: s.tokensUsed,
        durationMs: s.durationMs,
        error: s.errorMessage,
      );
    }).toList();

    // Parse Chen synthesis if Chen agent ran
    final chenState =
        current.agentStates[AppConstants.agentChen];
    final synthesisService =
        ChenSynthesisService(db: ref.read(firestoreProvider));
    final synthesis = chenState != null &&
            chenState.accumulatedText.isNotEmpty
        ? synthesisService
            .parseChenOutput(chenState.accumulatedText)
        : null;

    // Write final state to Firestore
    try {
      await docRef.update({
        'status': AnalysisStatus.complete.name,
        'agentOutputs': agentOutputs.map((a) => a.toMap()).toList(),
        if (synthesis != null) 'synthesis': synthesis.toMap(),
        'totalTokensUsed': current.totalTokens,
        'costUsd': current.estimatedCostUsd,
        'completedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Firestore write failure is non-fatal — analysis data is in state
    }

    _updateStatus(AnalysisStatus.complete);
  }

  // ── Cancel analysis ───────────────────────────────────────────────────────
  void cancel() {
    _sseSubscription?.cancel();
    _sseSubscription = null;
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(current.copyWith(isCancelled: true));
    }
  }

  // ── State helpers ─────────────────────────────────────────────────────────
  void _updateStatus(AnalysisStatus status) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(status: status));
  }

  void _updateAgent(
      String agentId, AgentStreamState Function(AgentStreamState) updater) {
    final current = state.valueOrNull;
    if (current == null) return;
    final existing = current.agentStates[agentId] ??
        AgentStreamState(agentId: agentId);
    final updated = Map<String, AgentStreamState>.from(current.agentStates)
      ..[agentId] = updater(existing);
    state = AsyncValue.data(current.copyWith(agentStates: updated));
  }

  void _incrementCompleted() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(
      current.copyWith(
          completedAgentCount: current.completedAgentCount + 1),
    );
  }

  AnalysisStatus _mapStatus(String raw) {
    switch (raw) {
      case 'parsing': return AnalysisStatus.parsing;
      case 'running': return AnalysisStatus.running;
      case 'synthesizing': return AnalysisStatus.synthesizing;
      case 'complete': return AnalysisStatus.complete;
      default: return AnalysisStatus.running;
    }
  }

  @override
  void dispose() {
    _sseSubscription?.cancel();
    super.dispose();
  }
}

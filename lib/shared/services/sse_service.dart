// lib/shared/services/sse_service.dart
//
// Server-Sent Events client for The Prism.
// Connects to Cloudflare Worker /api/analyze and streams
// agent tokens in real time to the Flutter UI.
//
// SSE Event types received:
//   status        → overall analysis phase change
//   agent_start   → agent began processing
//   agent_token   → one token from agent output
//   agent_complete→ agent fully done, fullText available
//   agent_error   → agent failed (non-fatal)
//   cost_update   → running token + cost count
//   error         → fatal analysis error

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

// ── SSE Event Model ───────────────────────────────────────────────────────────
class SseEvent {
  final String type;
  final Map<String, dynamic> data;

  const SseEvent({required this.type, required this.data});

  @override
  String toString() => 'SseEvent($type, $data)';
}

// ── Typed events for clean consumption ───────────────────────────────────────
class AgentTokenEvent {
  final String agentId;
  final String token;
  final String provider;
  AgentTokenEvent({required this.agentId, required this.token, required this.provider});
}

class AgentCompleteEvent {
  final String agentId;
  final String fullText;
  final int tokensUsed;
  final double durationMs;
  final String provider;
  AgentCompleteEvent({
    required this.agentId,
    required this.fullText,
    required this.tokensUsed,
    required this.durationMs,
    required this.provider,
  });
}

class AgentStartEvent {
  final String agentId;
  final String provider;
  AgentStartEvent({required this.agentId, required this.provider});
}

class AnalysisStatusEvent {
  final String status; // 'parsing' | 'running' | 'synthesizing' | 'complete'
  final String analysisId;
  AnalysisStatusEvent({required this.status, required this.analysisId});
}

class CostUpdateEvent {
  final int totalTokens;
  final double estimatedCostUsd;
  final int agentsComplete;
  final bool isFinal;
  CostUpdateEvent({
    required this.totalTokens,
    required this.estimatedCostUsd,
    required this.agentsComplete,
    required this.isFinal,
  });
}

// ── SSE Service ───────────────────────────────────────────────────────────────
class SseService {
  final String baseUrl;
  final String authToken; // Firebase ID token

  SseService({required this.baseUrl, required this.authToken});

  /// Opens an SSE stream to the Cloudflare Worker analyze endpoint.
  /// Returns a broadcast stream of typed [SseEvent]s.
  Stream<SseEvent> streamAnalysis({
    required String analysisId,
    required String r2Key,
    required String fileName,
    required String fileExtension,
    required String mimeType,
    String? focusQuestion,
    required String aiProvider,
    required List<String> agentIds,
  }) {
    final controller = StreamController<SseEvent>.broadcast();

    _connect(
      controller: controller,
      body: {
        'analysisId': analysisId,
        'r2Key': r2Key,
        'fileName': fileName,
        'fileExtension': fileExtension,
        'mimeType': mimeType,
        if (focusQuestion != null && focusQuestion.isNotEmpty)
          'focusQuestion': focusQuestion,
        'aiProvider': aiProvider,
        'agentIds': agentIds,
      },
    );

    return controller.stream;
  }

  Future<void> _connect({
    required StreamController<SseEvent> controller,
    required Map<String, dynamic> body,
  }) async {
    final client = http.Client();

    try {
      final request = http.Request(
        'POST',
        Uri.parse('$baseUrl/api/analyze'),
      );

      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
      });

      request.body = jsonEncode(body);

      final response = await client.send(request).timeout(
        const Duration(minutes: 10),
      );

      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        Map<String, dynamic> errorData = {};
        try {
          errorData = jsonDecode(errorBody) as Map<String, dynamic>;
        } catch (_) {
          errorData = {'message': errorBody};
        }
        controller.addError(
          SseException(
            statusCode: response.statusCode,
            message: errorData['message'] as String? ?? 'Analysis failed',
            code: errorData['error'] as String?,
          ),
        );
        controller.close();
        return;
      }

      // Parse SSE stream
      String buffer = '';

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;

        // SSE events are separated by double newlines
        final events = buffer.split('\n\n');

        // Keep last incomplete event in buffer
        buffer = events.removeLast();

        for (final rawEvent in events) {
          final parsed = _parseRawEvent(rawEvent);
          if (parsed != null) {
            controller.add(parsed);

            // Auto-close on terminal events
            if (parsed.type == 'status') {
              final status = parsed.data['status'] as String?;
              if (status == 'complete' || status == 'error') {
                await Future.delayed(const Duration(milliseconds: 100));
                controller.close();
                return;
              }
            }
            if (parsed.type == 'error') {
              controller.addError(
                SseException(
                  statusCode: 200,
                  message: parsed.data['message'] as String? ?? 'Analysis error',
                ),
              );
              controller.close();
              return;
            }
          }
        }
      }

      // Stream ended normally
      if (!controller.isClosed) controller.close();
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
        controller.close();
      }
    } finally {
      client.close();
    }
  }

  /// Parses a raw SSE event block into [SseEvent].
  /// Format:
  ///   event: agent_token
  ///   data: {"agentId":"priya","token":"The "}
  SseEvent? _parseRawEvent(String raw) {
    String? eventType;
    String? dataLine;

    for (final line in raw.split('\n')) {
      if (line.startsWith('event: ')) {
        eventType = line.substring(7).trim();
      } else if (line.startsWith('data: ')) {
        dataLine = line.substring(6).trim();
      }
    }

    if (eventType == null || dataLine == null || dataLine.isEmpty) return null;

    try {
      final data = jsonDecode(dataLine) as Map<String, dynamic>;
      return SseEvent(type: eventType, data: data);
    } catch (_) {
      return null;
    }
  }
}

// ── SSE Exception ─────────────────────────────────────────────────────────────
class SseException implements Exception {
  final int statusCode;
  final String message;
  final String? code;

  const SseException({
    required this.statusCode,
    required this.message,
    this.code,
  });

  bool get isQuotaExceeded => code == 'quota_exceeded';
  bool get isUnauthorized => statusCode == 401;
  bool get isServerError => statusCode >= 500;

  @override
  String toString() => 'SseException($statusCode): $message';
}

// ── Typed event helpers ───────────────────────────────────────────────────────
extension SseEventX on SseEvent {
  AgentTokenEvent? asAgentToken() {
    if (type != 'agent_token') return null;
    return AgentTokenEvent(
      agentId: data['agentId'] as String,
      token: data['token'] as String,
      provider: data['provider'] as String? ?? 'claude',
    );
  }

  AgentCompleteEvent? asAgentComplete() {
    if (type != 'agent_complete') return null;
    return AgentCompleteEvent(
      agentId: data['agentId'] as String,
      fullText: data['fullText'] as String,
      tokensUsed: data['tokensUsed'] as int? ?? 0,
      durationMs: (data['durationMs'] as num?)?.toDouble() ?? 0,
      provider: data['provider'] as String? ?? 'claude',
    );
  }

  AgentStartEvent? asAgentStart() {
    if (type != 'agent_start') return null;
    return AgentStartEvent(
      agentId: data['agentId'] as String,
      provider: data['provider'] as String? ?? 'claude',
    );
  }

  AnalysisStatusEvent? asStatus() {
    if (type != 'status') return null;
    return AnalysisStatusEvent(
      status: data['status'] as String,
      analysisId: data['analysisId'] as String,
    );
  }

  CostUpdateEvent? asCostUpdate() {
    if (type != 'cost_update') return null;
    return CostUpdateEvent(
      totalTokens: data['totalTokens'] as int? ?? 0,
      estimatedCostUsd:
          double.tryParse(data['estimatedCostUsd']?.toString() ?? '0') ?? 0,
      agentsComplete: data['agentsComplete'] as int? ?? 0,
      isFinal: data['final'] as bool? ?? false,
    );
  }
}

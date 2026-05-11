// lib/features/debate/data/debate_service.dart
// Phase 18 — Agent Debate Mode
//
// Two agents argue opposite sides of a user-chosen topic.
// Format: Opening → 3 Arguments → Rebuttal → Closing
// Both agents stream simultaneously — user sees live thinking.

import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_constants.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/models/analysis_model.dart';

// ── Debate Models ─────────────────────────────────────────────────────────────

enum DebateStage { opening, arguments, rebuttal, closing }

extension DebateStageName on DebateStage {
  String get label {
    switch (this) {
      case DebateStage.opening:   return 'Opening Position';
      case DebateStage.arguments: return 'Main Arguments';
      case DebateStage.rebuttal:  return 'Rebuttal';
      case DebateStage.closing:   return 'Closing Statement';
    }
  }
}

class DebateRound {
  final DebateStage stage;
  final String agentAId;
  final String agentBId;
  String agentAText;
  String agentBText;
  bool agentAComplete;
  bool agentBComplete;

  DebateRound({
    required this.stage,
    required this.agentAId,
    required this.agentBId,
    this.agentAText = '',
    this.agentBText = '',
    this.agentAComplete = false,
    this.agentBComplete = false,
  });

  bool get bothComplete => agentAComplete && agentBComplete;
}

class DebateState {
  final String topic;
  final String agentAId;
  final String agentBId;
  final List<DebateRound> rounds;
  final bool isComplete;
  final String? userVote; // agentAId or agentBId

  const DebateState({
    required this.topic,
    required this.agentAId,
    required this.agentBId,
    required this.rounds,
    this.isComplete = false,
    this.userVote,
  });

  DebateState copyWith({
    List<DebateRound>? rounds,
    bool? isComplete,
    String? userVote,
  }) => DebateState(
        topic: topic,
        agentAId: agentAId,
        agentBId: agentBId,
        rounds: rounds ?? this.rounds,
        isComplete: isComplete ?? this.isComplete,
        userVote: userVote ?? this.userVote,
      );
}

// ── Debate SSE Event ──────────────────────────────────────────────────────────

class DebateEvent {
  final String type;   // stage_start | token | stage_complete | debate_complete
  final String? agentId;
  final String? token;
  final DebateStage? stage;
  final String? fullText;

  const DebateEvent({
    required this.type,
    this.agentId,
    this.token,
    this.stage,
    this.fullText,
  });
}

// ── Debate Service ────────────────────────────────────────────────────────────

class DebateService {
  final http.Client _client = http.Client();

  /// Start a debate between two agents on a given topic.
  /// Returns a Stream of DebateEvents.
  Stream<DebateEvent> startDebate({
    required String agentAId,
    required String agentBId,
    required String topic,
    required String fileContext,     // the original file content for grounding
    required AnalysisModel analysis, // optional — used to ground the debate
  }) async* {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final idToken = await user.getIdToken(true);
    if (idToken == null) throw Exception('Auth token error');

    final uri = Uri.parse(
        '${AppConstants.apiBaseUrl}/api/debate');

    final request = http.Request('POST', uri)
      ..headers['Content-Type']    = 'application/json'
      ..headers['Authorization']   = 'Bearer $idToken'
      ..headers['Accept']          = 'text/event-stream'
      ..body = jsonEncode({
        'agentAId':    agentAId,
        'agentBId':    agentBId,
        'topic':       topic,
        'analysisId':  analysis.id,
        'fileContext': fileContext.substring(
            0, fileContext.length.clamp(0, 3000)),
      });

    final response = await _client
        .send(request)
        .timeout(AppConstants.streamTimeout);

    if (response.statusCode != 200) {
      throw Exception('Debate API error: ${response.statusCode}');
    }

    String buffer = '';
    await for (final chunk
        in response.stream.transform(utf8.decoder)) {
      buffer += chunk;
      while (buffer.contains('\n\n')) {
        final sep = buffer.indexOf('\n\n');
        final message = buffer.substring(0, sep);
        buffer = buffer.substring(sep + 2);

        String? eventType;
        String? dataStr;
        for (final line in message.split('\n')) {
          if (line.startsWith('event: ')) {
            eventType = line.substring(7).trim();
          } else if (line.startsWith('data: ')) {
            dataStr = line.substring(6).trim();
          }
        }

        if (eventType == null || dataStr == null) continue;

        try {
          final data = jsonDecode(dataStr) as Map<String, dynamic>;
          final stage = data['stage'] != null
              ? DebateStage.values.firstWhere(
                  (s) => s.name == data['stage'],
                  orElse: () => DebateStage.opening)
              : null;

          yield DebateEvent(
            type: eventType,
            agentId: data['agentId'] as String?,
            token: data['token'] as String?,
            stage: stage,
            fullText: data['fullText'] as String?,
          );
        } catch (_) {
          // Malformed event — skip
        }
      }
    }
  }

  void dispose() => _client.close();
}

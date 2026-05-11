// lib/features/voice/presentation/voice_service.dart
// Phase 21 — Voice Readout (TTS)
//
// Reads each agent's output aloud using flutter_tts.
// Controls: play/pause/skip agent, speed 0.75x–2x.
// Continues playing when screen is off.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/models/analysis_model.dart';

part 'voice_service.g.dart';

// ── Playback State ────────────────────────────────────────────────────────────
enum VoicePlaybackStatus { idle, playing, paused, complete }

class VoicePlaybackState {
  final VoicePlaybackStatus status;
  final int currentAgentIndex;
  final double speed;
  final List<AgentOutput> queue;
  final String? currentAgentId;

  const VoicePlaybackState({
    this.status = VoicePlaybackStatus.idle,
    this.currentAgentIndex = 0,
    this.speed = 1.0,
    this.queue = const [],
    this.currentAgentId,
  });

  bool get isPlaying => status == VoicePlaybackStatus.playing;
  bool get isPaused => status == VoicePlaybackStatus.paused;
  bool get isIdle => status == VoicePlaybackStatus.idle;
  bool get isComplete => status == VoicePlaybackStatus.complete;

  AgentOutput? get currentOutput =>
      queue.isNotEmpty && currentAgentIndex < queue.length
          ? queue[currentAgentIndex]
          : null;

  double get overallProgress => queue.isEmpty
      ? 0
      : currentAgentIndex / queue.length;

  VoicePlaybackState copyWith({
    VoicePlaybackStatus? status,
    int? currentAgentIndex,
    double? speed,
    List<AgentOutput>? queue,
    String? currentAgentId,
  }) {
    return VoicePlaybackState(
      status: status ?? this.status,
      currentAgentIndex: currentAgentIndex ?? this.currentAgentIndex,
      speed: speed ?? this.speed,
      queue: queue ?? this.queue,
      currentAgentId: currentAgentId ?? this.currentAgentId,
    );
  }
}

// ── Voice Notifier ────────────────────────────────────────────────────────────
@riverpod
class VoiceNotifier extends _$VoiceNotifier {
  FlutterTts? _tts;
  static const List<double> speeds = [0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  VoicePlaybackState build() {
    ref.onDispose(_dispose);
    return const VoicePlaybackState();
  }

  // ── Init TTS ────────────────────────────────────────────────────────────
  Future<void> _initTts() async {
    if (_tts != null) return;
    _tts = FlutterTts();

    await _tts!.setLanguage('en-US');
    await _tts!.setSpeechRate(state.speed);
    await _tts!.setVolume(1.0);
    await _tts!.setPitch(1.0);

    _tts!.setCompletionHandler(() {
      _onAgentComplete();
    });

    _tts!.setErrorHandler((msg) {
      debugPrint('TTS error: $msg');
      state = state.copyWith(status: VoicePlaybackStatus.idle);
    });
  }

  // ── Public API ───────────────────────────────────────────────────────────

  /// Start reading the full analysis report
  Future<void> startReport(AnalysisModel analysis) async {
    await _initTts();

    // Build ordered queue — specialists first, Chen last
    final orderedIds = AppConstants.allAgentIds;
    final queue = orderedIds
        .map((id) => analysis.outputFor(id))
        .where((o) => o != null && o.content.isNotEmpty)
        .cast<AgentOutput>()
        .toList();

    if (queue.isEmpty) return;

    state = state.copyWith(
      queue: queue,
      currentAgentIndex: 0,
      status: VoicePlaybackStatus.playing,
      currentAgentId: queue.first.agentId,
    );

    await _speakCurrent();
  }

  /// Start reading from a specific agent
  Future<void> startFromAgent(
    AnalysisModel analysis,
    String agentId,
  ) async {
    await _initTts();

    final orderedIds = AppConstants.allAgentIds;
    final queue = orderedIds
        .map((id) => analysis.outputFor(id))
        .where((o) => o != null && o.content.isNotEmpty)
        .cast<AgentOutput>()
        .toList();

    final startIndex =
        queue.indexWhere((o) => o.agentId == agentId);
    if (startIndex < 0) return;

    state = state.copyWith(
      queue: queue,
      currentAgentIndex: startIndex,
      status: VoicePlaybackStatus.playing,
      currentAgentId: agentId,
    );

    await _speakCurrent();
  }

  Future<void> pause() async {
    if (!state.isPlaying) return;
    await _tts?.pause();
    state = state.copyWith(status: VoicePlaybackStatus.paused);
  }

  Future<void> resume() async {
    if (!state.isPaused) return;
    await _tts?.speak(state.currentOutput?.content ?? '');
    state = state.copyWith(status: VoicePlaybackStatus.playing);
  }

  Future<void> stop() async {
    await _tts?.stop();
    state = state.copyWith(
      status: VoicePlaybackStatus.idle,
      currentAgentIndex: 0,
      currentAgentId: null,
    );
  }

  Future<void> skipNext() async {
    await _tts?.stop();
    final nextIndex = state.currentAgentIndex + 1;
    if (nextIndex >= state.queue.length) {
      state = state.copyWith(
          status: VoicePlaybackStatus.complete);
      return;
    }
    state = state.copyWith(
      currentAgentIndex: nextIndex,
      currentAgentId: state.queue[nextIndex].agentId,
      status: VoicePlaybackStatus.playing,
    );
    await _speakCurrent();
  }

  Future<void> skipPrevious() async {
    await _tts?.stop();
    final prevIndex = (state.currentAgentIndex - 1).clamp(0, 999);
    state = state.copyWith(
      currentAgentIndex: prevIndex,
      currentAgentId: state.queue[prevIndex].agentId,
      status: VoicePlaybackStatus.playing,
    );
    await _speakCurrent();
  }

  Future<void> setSpeed(double speed) async {
    state = state.copyWith(speed: speed);
    await _tts?.setSpeechRate(speed);
    // If playing, restart current with new speed
    if (state.isPlaying) {
      await _tts?.stop();
      await _speakCurrent();
    }
  }

  void cycleSpeed() {
    final currentIdx = speeds.indexWhere((s) => s == state.speed);
    final nextIdx = (currentIdx + 1) % speeds.length;
    setSpeed(speeds[nextIdx]);
  }

  // ── Private ──────────────────────────────────────────────────────────────
  Future<void> _speakCurrent() async {
    final output = state.currentOutput;
    if (output == null) return;

    AgentModel? agent;
    try {
      agent = AgentRegistry.get(output.agentId);
    } catch (_) {}

    // Announce agent name before reading
    final announcement = agent != null
        ? '${agent.name}. ${agent.role}. '
        : '';

    final fullText = announcement + output.content;
    await _tts?.speak(fullText);
  }

  void _onAgentComplete() {
    final nextIndex = state.currentAgentIndex + 1;
    if (nextIndex >= state.queue.length) {
      state = state.copyWith(
        status: VoicePlaybackStatus.complete,
        currentAgentId: null,
      );
      return;
    }

    state = state.copyWith(
      currentAgentIndex: nextIndex,
      currentAgentId: state.queue[nextIndex].agentId,
      status: VoicePlaybackStatus.playing,
    );
    _speakCurrent();
  }

  void _dispose() {
    _tts?.stop();
    _tts = null;
  }
}

// ── Mini Player Provider ──────────────────────────────────────────────────────
// Whether the mini player bottom bar is visible
@riverpod
bool voiceMiniPlayerVisible(VoiceMiniPlayerVisibleRef ref) {
  final voiceState = ref.watch(voiceNotifierProvider);
  return !voiceState.isIdle;
}

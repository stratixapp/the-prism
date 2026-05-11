// lib/shared/services/analytics_service.dart
// Phase 25 — Analytics + Growth Engine
//
// Firebase Analytics events for every meaningful user action.
// Firebase Remote Config for feature flags.
// All personally identifiable data is excluded from events.

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

// ── Event Names ───────────────────────────────────────────────────────────────
abstract class PrismEvent {
  // Onboarding
  static const onboardingStarted    = 'onboarding_started';
  static const onboardingCompleted  = 'onboarding_completed';
  static const onboardingSkipped    = 'onboarding_skipped';
  static const signUpStarted        = 'sign_up_started';
  static const signUpCompleted      = 'sign_up_completed';
  static const signInCompleted      = 'sign_in_completed';

  // Core funnel
  static const fileUploaded         = 'file_uploaded';
  static const analysisStarted      = 'analysis_started';
  static const analysisCompleted    = 'analysis_completed';
  static const analysisFailed       = 'analysis_failed';
  static const analysisCancelled    = 'analysis_cancelled';

  // Results engagement
  static const resultViewed         = 'result_viewed';
  static const agentOutputViewed    = 'agent_output_viewed';
  static const chenCardViewed       = 'chen_card_viewed';
  static const resultCopied         = 'result_copied';
  static const resultShared         = 'result_shared';
  static const pdfExported          = 'pdf_exported';

  // Pro features
  static const debateStarted        = 'debate_started';
  static const debateCompleted      = 'debate_completed';
  static const debateVoteCast       = 'debate_vote_cast';
  static const customAgentCreated   = 'custom_agent_created';
  static const compareModeStarted   = 'compare_mode_started';
  static const voicePlaybackStarted = 'voice_playback_started';
  static const voicePlaybackCompleted = 'voice_playback_completed';

  // Conversion
  static const upgradeTapped        = 'upgrade_tapped';
  static const upgradeSheetViewed   = 'upgrade_sheet_viewed';
  static const purchaseStarted      = 'purchase_started';
  static const purchaseCompleted    = 'purchase_completed';
  static const purchaseFailed       = 'purchase_failed';
  static const purchaseRestored     = 'purchase_restored';

  // Retention
  static const historyViewed        = 'history_viewed';
  static const analysisPinned       = 'analysis_pinned';
  static const analysisDeleted      = 'analysis_deleted';
  static const searchUsed           = 'search_used';

  // Settings
  static const providerChanged      = 'ai_provider_changed';
  static const accountDeleted       = 'account_deleted';
}

// ── Remote Config Keys ────────────────────────────────────────────────────────
abstract class RemoteConfigKeys {
  static const enableDebateMode     = 'enable_debate_mode';
  static const enableCompareMode    = 'enable_compare_mode';
  static const enableVoiceReadout   = 'enable_voice_readout';
  static const freeAnalysisLimit    = 'free_analysis_limit';
  static const showUpgradeBanner    = 'show_upgrade_banner';
  static const onboardingVariant    = 'onboarding_variant'; // A/B test
  static const proMonthlyPriceInr   = 'pro_monthly_price_inr';
}

// ── Analytics Service ─────────────────────────────────────────────────────────
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._();
  factory AnalyticsService() => _instance;
  AnalyticsService._();

  final _analytics = FirebaseAnalytics.instance;
  late final FirebaseRemoteConfig _remoteConfig;

  // ── Init ─────────────────────────────────────────────────────────────────
  Future<void> init() async {
    // Remote Config
    _remoteConfig = FirebaseRemoteConfig.instance;
    await _remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: kDebugMode
          ? Duration.zero
          : const Duration(hours: 1),
    ));

    await _remoteConfig.setDefaults({
      RemoteConfigKeys.enableDebateMode: true,
      RemoteConfigKeys.enableCompareMode: true,
      RemoteConfigKeys.enableVoiceReadout: true,
      RemoteConfigKeys.freeAnalysisLimit: 3,
      RemoteConfigKeys.showUpgradeBanner: true,
      RemoteConfigKeys.onboardingVariant: 'A',
      RemoteConfigKeys.proMonthlyPriceInr: 399,
    });

    await _remoteConfig.fetchAndActivate();

    // Disable analytics in debug mode
    await _analytics.setAnalyticsCollectionEnabled(!kDebugMode);
  }

  // ── Core Events ───────────────────────────────────────────────────────────
  Future<void> logFileUploaded({
    required String fileExtension,
    required int fileSizeKb,
  }) => _log(PrismEvent.fileUploaded, {
        'file_extension': fileExtension,
        'file_size_kb': fileSizeKb.toString(),
      });

  Future<void> logAnalysisStarted({
    required String aiProvider,
    required int agentCount,
    required String fileExtension,
  }) => _log(PrismEvent.analysisStarted, {
        'ai_provider': aiProvider,
        'agent_count': agentCount.toString(),
        'file_extension': fileExtension,
      });

  Future<void> logAnalysisCompleted({
    required int durationSeconds,
    required int tokensUsed,
    required int agentCount,
    required String aiProvider,
  }) => _log(PrismEvent.analysisCompleted, {
        'duration_seconds': durationSeconds.toString(),
        'tokens_used': tokensUsed.toString(),
        'agent_count': agentCount.toString(),
        'ai_provider': aiProvider,
      });

  Future<void> logUpgradeTapped({required String source}) =>
      _log(PrismEvent.upgradeTapped, {'source': source});

  Future<void> logPurchaseCompleted({
    required String productId,
    required String plan,
  }) => _log(PrismEvent.purchaseCompleted, {
        'product_id': productId,
        'plan': plan,
      });

  Future<void> logPdfExported() =>
      _log(PrismEvent.pdfExported, {});

  Future<void> logDebateStarted({
    required String agentAId,
    required String agentBId,
  }) => _log(PrismEvent.debateStarted, {
        'agent_a': agentAId,
        'agent_b': agentBId,
      });

  Future<void> logCustomAgentCreated({
    required String reasoningStyle,
  }) => _log(PrismEvent.customAgentCreated, {
        'reasoning_style': reasoningStyle,
      });

  Future<void> logVoicePlayback({
    required int agentCount,
    required double speed,
  }) => _log(PrismEvent.voicePlaybackStarted, {
        'agent_count': agentCount.toString(),
        'speed': speed.toString(),
      });

  // ── User Properties ───────────────────────────────────────────────────────
  Future<void> setUserPlan(String plan) =>
      _analytics.setUserProperty(name: 'plan', value: plan);

  Future<void> setUserIndustry(String industry) =>
      _analytics.setUserProperty(name: 'industry', value: industry);

  Future<void> setUserId(String uid) =>
      _analytics.setUserId(id: uid);

  // ── Remote Config Getters ─────────────────────────────────────────────────
  bool get debateModeEnabled =>
      _remoteConfig.getBool(RemoteConfigKeys.enableDebateMode);

  bool get compareModeEnabled =>
      _remoteConfig.getBool(RemoteConfigKeys.enableCompareMode);

  bool get voiceReadoutEnabled =>
      _remoteConfig.getBool(RemoteConfigKeys.enableVoiceReadout);

  int get freeAnalysisLimit =>
      _remoteConfig.getInt(RemoteConfigKeys.freeAnalysisLimit);

  bool get showUpgradeBanner =>
      _remoteConfig.getBool(RemoteConfigKeys.showUpgradeBanner);

  String get onboardingVariant =>
      _remoteConfig.getString(RemoteConfigKeys.onboardingVariant);

  // ── Private ───────────────────────────────────────────────────────────────
  Future<void> _log(
      String name, Map<String, String> params) async {
    try {
      await _analytics.logEvent(
          name: name,
          parameters:
              params.isEmpty ? null : params);
    } catch (e) {
      debugPrint('Analytics error [$name]: $e');
    }
  }
}

// ── Singleton accessor ────────────────────────────────────────────────────────
final analytics = AnalyticsService();

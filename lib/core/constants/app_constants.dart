/// The Prism — App Constants
/// Single source of truth for all magic strings, limits, and config values.
abstract class AppConstants {
  // ── App Info ─────────────────────────────────────────────────────────
  static const appName = 'The Prism';
  static const appTagline = 'Refract your files into intelligence';
  static const brandName = 'Stratix';
  static const appVersion = '1.0.0';

  // ── API ──────────────────────────────────────────────────────────────
  /// Base URL of your Cloudflare Worker — set per environment via --dart-define
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://prism-api.your-worker.workers.dev',
  );
  static const apiTimeout = Duration(seconds: 120);
  static const streamTimeout = Duration(minutes: 10);

  // ── Firestore Collections ────────────────────────────────────────────
  static const colUsers = 'users';
  static const colAnalyses = 'analyses';
  static const colAgentOutputs = 'agentOutputs';

  // ── Firestore User Fields ────────────────────────────────────────────
  static const fieldUid = 'uid';
  static const fieldEmail = 'email';
  static const fieldDisplayName = 'displayName';
  static const fieldPlan = 'plan';
  static const fieldAnalysisCount = 'analysisCount';
  static const fieldAnalysisCountResetAt = 'analysisCountResetAt';
  static const fieldIndustry = 'industry';
  static const fieldPreferredAiProvider = 'preferredAiProvider';
  static const fieldCreatedAt = 'createdAt';
  static const fieldUpdatedAt = 'updatedAt';

  // ── Plans ────────────────────────────────────────────────────────────
  static const planFree = 'free';
  static const planPro = 'pro';
  static const planTeam = 'team';

  // ── Free Tier Limits ─────────────────────────────────────────────────
  static const freeAnalysesPerMonth = 3;
  static const freeAgentsPerAnalysis = 3; // Priya, Marcus, Zara only
  static const proAgentsPerAnalysis = 10;

  // ── File Limits ──────────────────────────────────────────────────────
  static const maxFileSizeBytes = 50 * 1024 * 1024; // 50 MB
  static const maxFileSizeMb = 50;
  static const supportedExtensions = [
    'pdf', 'docx', 'xlsx', 'csv', 'txt', 'md',
    'json', 'xml', 'zip', 'apk', 'png', 'jpg',
    'jpeg', 'py', 'js', 'ts', 'dart', 'kt',
    'java', 'swift', 'html', 'css', 'pptx',
  ];

  // ── Agent IDs ────────────────────────────────────────────────────────
  static const agentPriya = 'priya';
  static const agentMarcus = 'marcus';
  static const agentZara = 'zara';
  static const agentLeon = 'leon';
  static const agentAiko = 'aiko';
  static const agentSofia = 'sofia';
  static const agentRavi = 'ravi';
  static const agentVex = 'vex';
  static const agentMorgan = 'morgan';
  static const agentChen = 'chen';

  static const List<String> allAgentIds = [
    agentPriya, agentMarcus, agentZara, agentLeon, agentAiko,
    agentSofia, agentRavi, agentVex, agentMorgan, agentChen,
  ];

  static const List<String> freeAgentIds = [
    agentPriya, agentMarcus, agentZara,
  ];

  // ── AI Providers ─────────────────────────────────────────────────────
  static const aiProviderClaude = 'claude';
  static const aiProviderOpenAI = 'openai';
  static const aiProviderBoth = 'both';

  // ── Claude Model ─────────────────────────────────────────────────────
  static const claudeModel = 'claude-sonnet-4-20250514';
  static const openaiModel = 'gpt-4o';

  // ── Storage Keys (SharedPreferences / SecureStorage) ─────────────────
  static const keyOnboardingDone = 'onboarding_done';
  static const keyThemeMode = 'theme_mode';
  static const keyPreferredProvider = 'preferred_provider';
  static const keyUserPlan = 'user_plan';

  // ── Hive Box Names ───────────────────────────────────────────────────
  static const hiveBoxAnalyses = 'analyses_cache';
  static const hiveBoxSettings = 'settings';

  // ── Pricing (INR) ────────────────────────────────────────────────────
  static const pricePro = '₹399';
  static const priceTeam = '₹1499';
  static const playProductPro = 'prism_pro_monthly';
  static const playProductTeam = 'prism_team_monthly';

  // ── Parameters marketing number ──────────────────────────────────────
  static const totalParameters = '10 Crore';
  static const agentCount = 10;

  // ── Animation Durations ──────────────────────────────────────────────
  static const animFast = Duration(milliseconds: 200);
  static const animNormal = Duration(milliseconds: 350);
  static const animSlow = Duration(milliseconds: 600);
  static const animVerySlow = Duration(milliseconds: 1200);

  // ── Pagination ───────────────────────────────────────────────────────
  static const historyPageSize = 20;

  // ── R2 / Storage ─────────────────────────────────────────────────────
  static const filePurgeAfterDays = 7;
}

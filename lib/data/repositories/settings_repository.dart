import 'package:sqflite/sqflite.dart';

import '../../core/utils/ids.dart';
import '../../theme/app_themes.dart';
import '../database/app_db.dart';

/// App settings contract: generic keys + typed helpers.
/// Local-only: no accounts, no credentials, nothing leaves the device.
abstract class SettingsRepository {
  Future<String?> get(String key);
  Future<void> set(String key, String value);

  Future<bool> isOnboardingDone();
  Future<void> setOnboardingDone(bool done);

  Future<AppThemeMode> themeMode();
  Future<void> setThemeMode(AppThemeMode mode);

  /// Programmed (prewritten, non-AI) companion replies. Default ON.
  Future<bool> autoReply();
  Future<void> setAutoReply(bool v);

  Future<bool> dailyGreeting();
  Future<void> setDailyGreeting(bool v);

  Future<bool> dailyQuestion();
  Future<void> setDailyQuestion(bool v);

  /// 0.8..1.3 text scaler. Default 1.0.
  Future<double> textScale();
  Future<void> setTextScale(double v);

  Future<bool> reducedMotion();
  Future<void> setReducedMotion(bool v);

  Future<bool> aiEnabled();
  Future<void> setAiEnabled(bool v);
  Future<String> aiModeName();
  Future<void> setAiModeName(String v);
  Future<String> aiBaseUrl();
  Future<void> setAiBaseUrl(String v);
  Future<String> aiModel();
  Future<void> setAiModel(String v);
  Future<String> aiProviderId();
  Future<void> setAiProviderId(String v);
}

class SqlSettingsRepository implements SettingsRepository {
  final AppDb appDb;
  SqlSettingsRepository(this.appDb);

  static const String keyOnboardingDone = 'onboarding_done';
  static const String keyThemeMode = 'theme_mode';
  static const String keyAutoReply = 'companion_auto_reply';
  static const String keyDailyGreeting = 'daily_greeting';
  static const String keyDailyQuestion = 'daily_question';
  static const String keyTextScale = 'text_scale';
  static const String keyReducedMotion = 'reduced_motion';
  static const String keyAiEnabled = 'ai_enabled';
  static const String keyAiMode = 'ai_mode';
  static const String keyAiBaseUrl = 'ai_base_url';
  static const String keyAiModel = 'ai_model';
  static const String keyAiProviderId = 'ai_provider_id';

  @override
  Future<String?> get(String key) async {
    final rows = await appDb.db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  @override
  Future<void> set(String key, String value) async {
    await appDb.db.insert(
      'app_settings',
      {'key': key, 'value': value, 'updatedAt': nowMs()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<bool> isOnboardingDone() async =>
      (await get(keyOnboardingDone)) == '1';

  @override
  Future<void> setOnboardingDone(bool done) =>
      set(keyOnboardingDone, done ? '1' : '0');

  @override
  Future<AppThemeMode> themeMode() async {
    final raw = await get(keyThemeMode);
    return switch (raw) {
      'light' => AppThemeMode.light,
      'dark' => AppThemeMode.dark,
      'oled' => AppThemeMode.oled,
      _ => AppThemeMode.system,
    };
  }

  @override
  Future<void> setThemeMode(AppThemeMode mode) =>
      set(keyThemeMode, mode.name);

  Future<bool> _flag(String key, bool fallback) async {
    final raw = await get(key);
    if (raw == null) return fallback;
    return raw == '1';
  }

  @override
  Future<bool> autoReply() => _flag(keyAutoReply, true);
  @override
  Future<void> setAutoReply(bool v) =>
      set(keyAutoReply, v ? '1' : '0');

  @override
  Future<bool> dailyGreeting() => _flag(keyDailyGreeting, true);
  @override
  Future<void> setDailyGreeting(bool v) =>
      set(keyDailyGreeting, v ? '1' : '0');

  @override
  Future<bool> dailyQuestion() => _flag(keyDailyQuestion, true);
  @override
  Future<void> setDailyQuestion(bool v) =>
      set(keyDailyQuestion, v ? '1' : '0');

  @override
  Future<double> textScale() async {
    final raw = await get(keyTextScale);
    final v = double.tryParse(raw ?? '');
    if (v == null) return 1.0;
    return v.clamp(0.8, 1.3);
  }

  @override
  Future<void> setTextScale(double v) =>
      set(keyTextScale, v.clamp(0.8, 1.3).toString());

  @override
  Future<bool> reducedMotion() => _flag(keyReducedMotion, false);
  @override
  Future<void> setReducedMotion(bool v) =>
      set(keyReducedMotion, v ? '1' : '0');

  // --- Phase 6 AI configuration (never credentials: the key lives in
  // platform secure storage, see AiCredentialStore). ---

  @override
  Future<bool> aiEnabled() => _flag(keyAiEnabled, false);
  @override
  Future<void> setAiEnabled(bool v) =>
      set(keyAiEnabled, v ? '1' : '0');

  /// Raw mode name: 'localOnly' | 'auto' | 'remoteOnly'. Parsed by the AI
  /// layer (AiMode); unknown values fall back to localOnly.
  @override
  Future<String> aiModeName() async =>
      (await get(keyAiMode)) ?? AiModeDefaults.localOnly;
  @override
  Future<void> setAiModeName(String v) => set(keyAiMode, v);

  @override
  Future<String> aiBaseUrl() async =>
      (await get(keyAiBaseUrl)) ?? AiModeDefaults.baseUrl;
  @override
  Future<void> setAiBaseUrl(String v) => set(keyAiBaseUrl, v.trim());

  @override
  Future<String> aiModel() async =>
      (await get(keyAiModel)) ?? AiModeDefaults.model;
  @override
  Future<void> setAiModel(String v) => set(keyAiModel, v.trim());

  @override
  Future<String> aiProviderId() async =>
      (await get(keyAiProviderId)) ?? AiModeDefaults.providerId;
  @override
  Future<void> setAiProviderId(String v) => set(keyAiProviderId, v.trim());
}

/// Defaults + key names for AI configuration. Kept beside the repository so
/// SQL and fake implementations share them exactly.
abstract final class AiModeDefaults {
  static const String localOnly = 'localOnly';
  static const String auto = 'auto';
  static const String remoteOnly = 'remoteOnly';

  static const String baseUrl = 'https://api.openai.com/v1';
  static const String model = 'gpt-4o-mini';
  static const String providerId = 'openai-compatible';
}

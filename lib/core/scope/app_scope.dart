import 'package:flutter/widgets.dart';

import '../../data/database/app_db.dart';
import '../../data/repositories/companion_repository.dart';
import '../../data/repositories/conversation_repository.dart';
import '../../data/repositories/draft_repository.dart';
import '../../data/repositories/message_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../features/ai/ai_credentials.dart';
import '../../features/ai/ai_runtime.dart';

/// Composition root for persistence. Repository fields are interfaces:
/// production wires SQL implementations, widget tests wire in-memory fakes
/// (ffi sqlite deadlocks under TestWidgetsFlutterBinding — see test/fakes).
/// Widgets never open databases or run SQL directly.
class AppScopeData {
  final ConversationRepository conversations;
  final MessageRepository messages;
  final DraftRepository drafts;
  final SettingsRepository settings;
  final CompanionRepository companion;
  final Future<void> Function() resetAll;
  final Future<void> Function() close;

  /// AI runtime (local responder always; remote assembled on demand).
  final AiRuntime ai;

  /// API-key storage (platform secure storage in prod, memory in tests).
  final AiCredentialStore credentials;

  /// Raw database. Non-null in production scopes; null in fake test scopes
  /// (use the repository interfaces instead — they work in both).
  final AppDb? db;

  AppScopeData({
    required this.conversations,
    required this.messages,
    required this.drafts,
    required this.settings,
    required this.companion,
    required this.resetAll,
    required this.close,
    this.db,
    required this.ai,
    required this.credentials,
  });

  /// Production wiring around a real [AppDb]. The caller supplies the AI
  /// runtime + credentials (built in main.dart, the composition root) so
  /// this file stays free of network/secure-storage imports.
  factory AppScopeData.real(
    AppDb db, {
    required AiRuntime ai,
    required AiCredentialStore credentials,
  }) =>
      AppScopeData(
        conversations: SqlConversationRepository(db),
        messages: SqlMessageRepository(db),
        drafts: SqlDraftRepository(db),
        settings: SqlSettingsRepository(db),
        companion: SqlCompanionRepository(db),
        resetAll: db.clearAllData,
        close: db.close,
        db: db,
        ai: ai,
        credentials: credentials,
      );
}

class AppScope extends InheritedWidget {
  final AppScopeData data;
  const AppScope({super.key, required this.data, required super.child});

  static AppScopeData of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope.of() called outside AppScope.');
    return scope!.data;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => data != oldWidget.data;
}

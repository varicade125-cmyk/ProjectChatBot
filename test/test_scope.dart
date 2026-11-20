import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_companion/core/scope/app_scope.dart';
import 'package:ai_companion/data/database/app_db.dart';
import 'package:ai_companion/data/repositories/companion_repository.dart';
import 'package:ai_companion/data/repositories/conversation_repository.dart';
import 'package:ai_companion/data/repositories/draft_repository.dart';
import 'package:ai_companion/data/repositories/message_repository.dart';
import 'package:ai_companion/data/repositories/settings_repository.dart';
import 'package:ai_companion/features/ai/ai_runtime.dart';
import 'package:ai_companion/features/ai/local_companion_provider.dart';

import 'fakes.dart';

/// Real scope around an already-open [AppDb] (file-backed restart tests,
/// perf smoke). Same wiring as [makeTestScope] minus temp-dir ownership.
AppScopeData realScopeFor(AppDb db) {
  final companion = SqlCompanionRepository(db);
  final creds = FakeAiCredentialStore();
  return AppScopeData.real(
    db,
    credentials: creds,
    ai: AiRuntime(
      local: LocalCompanionProvider(
        profileReader: () => companion.getOrCreate(),
      ),
      credentials: creds,
      remoteFactory: (_) => FakeRemoteProvider(),
    ),
  );
}

/// SQL-backed scope for binding-free tests (db_test.dart,
/// export_import_test.dart). Each call opens a UNIQUE temp-file database so
/// tests are fully isolated (a shared in-memory path leaks rows between
/// tests once a connection outlives its test). Temp dir is removed on close.
///
/// Widget tests must NOT use this: ffi sqlite deadlocks under
/// TestWidgetsFlutterBinding in this environment. They use makeFakeScope()
/// from fakes.dart instead.
Future<AppScopeData> makeTestScope() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final dir = await Directory.systemTemp.createTemp('scoptest');
  final db = await AppDb.open(pathOverride: p.join(dir.path, 't.db'));
  final companion = SqlCompanionRepository(db);
  final creds = FakeAiCredentialStore();
  return AppScopeData(
    conversations: SqlConversationRepository(db),
    messages: SqlMessageRepository(db),
    drafts: SqlDraftRepository(db),
    settings: SqlSettingsRepository(db),
    companion: companion,
    resetAll: db.clearAllData,
    close: () async {
      await db.close();
      await dir.delete(recursive: true);
    },
    db: db,
    credentials: creds,
    ai: AiRuntime(
      local: LocalCompanionProvider(
        profileReader: () => companion.getOrCreate(),
      ),
      credentials: creds,
      remoteFactory: (_) => FakeRemoteProvider(),
    ),
  );
}

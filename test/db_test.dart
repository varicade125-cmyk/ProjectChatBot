import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_companion/data/database/app_db.dart';
import 'package:ai_companion/data/models/message.dart';
import 'package:ai_companion/theme/app_themes.dart';

import 'test_scope.dart';

/// P2+P3+P4 database tests: schema, repositories, drafts, settings,
/// reopen persistence (migration-tolerant), cascade delete, companion,
/// pin/archive/search, clear operations.
/// Run on host via sqflite_common_ffi (dev dependency).
void main() {
  test('v1 schema creates every expected table + index', () async {
    final scope = await makeTestScope();
    final names = await scope.db!.db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type IN ('table','index')",
    );
    final set = names.map((r) => r['name'] as String).toSet();
    for (final t in [
      'user_profile',
      'companion_profile',
      'conversations',
      'messages',
      'memories',
      'notification_schedules',
      'journal_entries',
      'app_settings',
      'kv_drafts',
    ]) {
      expect(set, contains(t), reason: 'missing table $t');
    }
    expect(set, contains('idx_conv_updated'));
    expect(set, contains('idx_msg_conv'));
    expect(set, contains('idx_mem_key'));
    final v = await scope.db!.userVersion();
    expect(v, AppDb.schemaVersion);
    await scope.close();
  });

  test('conversations: create, ensureDefault idempotent, rename, touch',
      () async {
    final scope = await makeTestScope();
    final a = await scope.conversations.ensureDefault();
    expect(a.title, 'General');
    final again = await scope.conversations.ensureDefault();
    expect(again.id, a.id, reason: 'must not duplicate the default thread');

    await scope.conversations.rename(a.id, 'Renamed');
    expect((await scope.conversations.byId(a.id))!.title, 'Renamed');

    await scope.conversations.touch(
        id: a.id, preview: 'hello', messageCount: 1);
    final touched = (await scope.conversations.byId(a.id))!;
    expect(touched.lastMessagePreview, 'hello');
    expect(touched.messageCount, 1);
    await scope.close();
  });

  test('messages: insert, newest-first paging, count, status, delete',
      () async {
    final scope = await makeTestScope();
    final conv = await scope.conversations.ensureDefault();
    for (var i = 0; i < 5; i++) {
      await scope.messages.insert(
        conversationId: conv.id,
        role: MessageRole.user,
        body: 'm$i',
      );
    }
    expect(await scope.messages.count(conv.id), 5);

    final first = await scope.messages.page(conv.id, limit: 2, offset: 0);
    expect(first.map((m) => m.body).toList(), ['m4', 'm3']);
    final second = await scope.messages.page(conv.id, limit: 2, offset: 2);
    expect(second.map((m) => m.body).toList(), ['m2', 'm1']);

    await scope.messages
        .updateStatus(first.first.id, MessageStatus.queuedOffline);
    final reloaded =
        await scope.messages.page(conv.id, limit: 1, offset: 0);
    expect(reloaded.first.status, MessageStatus.queuedOffline);

    await scope.messages.delete(reloaded.first.id);
    expect(await scope.messages.count(conv.id), 4);
    await scope.close();
  });

  test('drafts: set/get/clear; blank clears', () async {
    final scope = await makeTestScope();
    final conv = await scope.conversations.ensureDefault();
    expect(await scope.drafts.get(conv.id), isNull);
    await scope.drafts.set(conv.id, 'half-typed…');
    expect(await scope.drafts.get(conv.id), 'half-typed…');
    await scope.drafts.set(conv.id, '   ');
    expect(await scope.drafts.get(conv.id), isNull);
    await scope.drafts.set(conv.id, 'x');
    await scope.drafts.clear(conv.id);
    expect(await scope.drafts.get(conv.id), isNull);
    await scope.close();
  });

  test('settings: onboarding flag + theme round-trip; unknown → system',
      () async {
    final scope = await makeTestScope();
    expect(await scope.settings.isOnboardingDone(), isFalse);
    await scope.settings.setOnboardingDone(true);
    expect(await scope.settings.isOnboardingDone(), isTrue);

    expect(await scope.settings.themeMode(), AppThemeMode.system);
    await scope.settings.setThemeMode(AppThemeMode.oled);
    expect(await scope.settings.themeMode(), AppThemeMode.oled);
    await scope.settings.set('theme_mode', 'banana');
    expect(await scope.settings.themeMode(), AppThemeMode.system);
    await scope.close();
  });

  test('file reopen preserves data (migration-tolerant restart)', () async {
    final dir = await Directory.systemTemp.createTemp('p2db');
    final path = p.join(dir.path, 'restart.db');
    {
      final scope = realScopeFor(await AppDb.open(pathOverride: path));
      final conv = await scope.conversations.ensureDefault();
      await scope.messages.insert(
        conversationId: conv.id,
        role: MessageRole.user,
        body: 'survive restart',
      );
      await scope.drafts.set(conv.id, 'draft survives');
      await scope.settings.setOnboardingDone(true);
      await scope.settings.setThemeMode(AppThemeMode.dark);
      await scope.close();
    }
    {
      final scope = realScopeFor(await AppDb.open(pathOverride: path));
      final conv = await scope.conversations.ensureDefault();
      expect(await scope.messages.count(conv.id), 1);
      expect(await scope.drafts.get(conv.id), 'draft survives');
      expect(await scope.settings.isOnboardingDone(), isTrue);
      expect(await scope.settings.themeMode(), AppThemeMode.dark);
      final v = await scope.db!.userVersion();
      expect(v, AppDb.schemaVersion);
      await scope.close();
    }
    await dir.delete(recursive: true);
  });

  test('delete conversation cascades messages + drafts', () async {
    final scope = await makeTestScope();
    final conv = await scope.conversations.ensureDefault();
    await scope.messages.insert(
      conversationId: conv.id,
      role: MessageRole.user,
      body: 'bye',
    );
    await scope.drafts.set(conv.id, 'bye draft');
    await scope.conversations.delete(conv.id);
    expect(await scope.conversations.byId(conv.id), isNull);
    expect(await scope.messages.count(conv.id), 0);
    expect(await scope.drafts.get(conv.id), isNull);
    await scope.close();
  });

  test('companion: defaults, save bumps version, reset restores', () async {
    final scope = await makeTestScope();
    final fresh = await scope.companion.getOrCreate();
    expect(fresh.name, 'Companion');
    expect(fresh.version, 1);
    expect((await scope.companion.getOrCreate()).id, fresh.id);

    final saved = await scope.companion.save(
      fresh.copyWith(
        name: 'Buddy',
        avatarRef: () => 'leaf',
        userName: () => 'Sam',
        interests: ['hiking'],
      ),
    );
    expect(saved.version, 2);
    expect(saved.name, 'Buddy');
    expect(saved.userName, 'Sam');
    final reloaded = await scope.companion.getOrCreate();
    expect(reloaded.name, 'Buddy');
    expect(reloaded.interests, ['hiking']);

    final reset = await scope.companion.resetToDefaults();
    expect(reset.name, 'Companion');
    expect(reset.userName, isNull);
    await scope.close();
  });

  test('settings: P3 keys default + round-trip + clamp', () async {
    final scope = await makeTestScope();
    expect(await scope.settings.autoReply(), isTrue);
    expect(await scope.settings.dailyGreeting(), isTrue);
    expect(await scope.settings.dailyQuestion(), isTrue);
    expect(await scope.settings.textScale(), 1.0);
    expect(await scope.settings.reducedMotion(), isFalse);

    await scope.settings.setAutoReply(false);
    await scope.settings.setDailyGreeting(false);
    await scope.settings.setDailyQuestion(false);
    await scope.settings.setTextScale(5.0);
    await scope.settings.setReducedMotion(true);
    expect(await scope.settings.autoReply(), isFalse);
    expect(await scope.settings.dailyGreeting(), isFalse);
    expect(await scope.settings.dailyQuestion(), isFalse);
    expect(await scope.settings.textScale(), 1.3);
    expect(await scope.settings.reducedMotion(), isTrue);
    await scope.close();
  });

  test('clearAll wipes conversations, messages, drafts', () async {
    final scope = await makeTestScope();
    final conv = await scope.conversations.ensureDefault();
    await scope.messages.insert(
      conversationId: conv.id,
      role: MessageRole.user,
      body: 'x',
    );
    await scope.drafts.set(conv.id, 'y');
    await scope.conversations.clearAll();
    expect(await scope.conversations.listRecent(), isEmpty);
    expect(await scope.messages.count(conv.id), 0);
    expect(await scope.drafts.get(conv.id), isNull);
    await scope.close();
  });

  test('clearAllData wipes user tables, keeps schema + version', () async {
    final scope = await makeTestScope();
    final conv = await scope.conversations.ensureDefault();
    await scope.messages.insert(
      conversationId: conv.id,
      role: MessageRole.user,
      body: 'x',
    );
    await scope.settings.setOnboardingDone(true);
    await scope.db!.clearAllData();
    expect(await scope.conversations.listRecent(), isEmpty);
    expect(await scope.settings.isOnboardingDone(), isFalse);
    expect(await scope.companion.getOrCreate(), isNotNull);
    final v = await scope.db!.userVersion();
    expect(v, AppDb.schemaVersion);
    await scope.close();
  });

  test('pin/archive/search over titles, previews, bodies', () async {
    final scope = await makeTestScope();
    final a = await scope.conversations.create(title: 'Grocery list');
    await scope.messages.insert(
      conversationId: a.id,
      role: MessageRole.user,
      body: 'buy milk and eggs',
    );
    final b = await scope.conversations.create(title: 'Work notes');
    await scope.messages.insert(
      conversationId: b.id,
      role: MessageRole.user,
      body: 'ship the release',
    );
    final pct = await scope.conversations
        .create(title: '100% sure_under pressure');

    // Pin floats to the top of active.
    await scope.conversations.setPinned(b.id, true);
    final recent = await scope.conversations.listRecent();
    expect(recent.first.id, b.id);

    // Search hits title / body, case-insensitive.
    expect(
      (await scope.conversations.search('milk')).map((c) => c.id),
      [a.id],
    );
    expect(
      (await scope.conversations.search('WORK')).map((c) => c.id),
      [b.id],
    );
    expect(await scope.conversations.search('zzz'), isEmpty);
    expect(
      (await scope.conversations.search('  ')).length,
      3,
      reason: 'blank query returns full active list',
    );

    // LIKE wildcards are escaped: '%' matches only the literal-% title.
    expect(
      (await scope.conversations.search('100%')).map((c) => c.id),
      [pct.id],
    );

    // Archive moves threads between lists.
    await scope.conversations.setArchived(a.id, true);
    expect(
      (await scope.conversations.listRecent()).map((c) => c.id),
      contains(b.id),
    );
    expect(
      (await scope.conversations.listRecent()).map((c) => c.id),
      isNot(contains(a.id)),
    );
    expect(
      (await scope.conversations.listArchived()).map((c) => c.id),
      [a.id],
    );
    expect(await scope.conversations.search('milk'), isEmpty);
    expect(
      (await scope.conversations.search('milk', archived: true))
          .map((c) => c.id),
      [a.id],
    );
    await scope.conversations.setArchived(a.id, false);
    expect(
      (await scope.conversations.search('milk')).map((c) => c.id),
      [a.id],
    );
    await scope.close();
  });

  test('v1 → v2 migration adds provider/error, keeps rows', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('migrate12');
    final path = p.join(dir.path, 'v1.db');
    // Hand-build a v1 database (no provider/error columns), version 1.
    final raw = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE conversations(
  id TEXT PRIMARY KEY, title TEXT NOT NULL,
  isArchived INTEGER NOT NULL DEFAULT 0, isPinned INTEGER NOT NULL DEFAULT 0,
  createdAt INTEGER NOT NULL, updatedAt INTEGER NOT NULL,
  lastMessagePreview TEXT, messageCount INTEGER NOT NULL DEFAULT 0,
  summary TEXT)''');
        await db.execute('''
CREATE TABLE messages(
  id TEXT PRIMARY KEY, conversationId TEXT NOT NULL,
  role TEXT NOT NULL, body TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'sent',
  createdAt INTEGER NOT NULL, updatedAt INTEGER NOT NULL,
  requestId TEXT)''');
        await db.execute(
            "INSERT INTO conversations(id,title,createdAt,updatedAt) "
            "VALUES('c1','Old thread',1,2)");
        await db.execute(
            "INSERT INTO messages(id,conversationId,role,body,status,"
            "createdAt,updatedAt) "
            "VALUES('m1','c1','user','old hello','sent',1,2)");
      },
    );
    expect(await raw.getVersion(), 1);
    await raw.close();

    // Reopen through the app: upgrade must run, data must survive.
    final scope = realScopeFor(await AppDb.open(pathOverride: path));
    expect(await scope.db!.userVersion(), 2);
    final msgs = await scope.messages.page('c1', limit: 10);
    expect(msgs.single.body, 'old hello');
    expect(msgs.single.provider, isNull,
        reason: 'pre-Phase-6 rows read as local-era (null provider)');

    // New writes carry metadata on the migrated schema.
    await scope.messages.insert(
      conversationId: 'c1',
      role: MessageRole.assistant,
      body: 'new remote row',
      provider: MessageProvider.remote,
    );
    final rows = await scope.messages.page('c1', limit: 10);
    expect(
      rows
          .firstWhere((m) => m.body == 'new remote row')
          .provider,
      MessageProvider.remote,
    );
    await scope.close();
    await dir.delete(recursive: true);
  });
}

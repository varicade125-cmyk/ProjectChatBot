import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_companion/data/models/message.dart';
import 'package:ai_companion/features/data/export_import.dart';

import 'test_scope.dart';

/// Export/import round-trip tests (binding-free, SQL-backed).
/// Scope: conversations + messages (+flags). Companion profile is exported
/// for portability but never overwritten on import; drafts and app settings
/// are intentionally excluded (transient / device-specific).
void main() {
  test('export → clear → import restores everything, keeps existing',
      () async {
    final scope = await makeTestScope();
    final trip = await scope.conversations.create(title: 'Trip');
    await scope.conversations.setPinned(trip.id, true);
    await scope.messages.insert(
      conversationId: trip.id,
      role: MessageRole.user,
      body: 'pack light',
    );
    await scope.messages.insert(
      conversationId: trip.id,
      role: MessageRole.assistant,
      body: 'Noted — saved here.',
    );
    final ideas = await scope.conversations.create(title: 'Ideas');
    await scope.messages.insert(
      conversationId: ideas.id,
      role: MessageRole.user,
      body: 'build a treehouse',
    );
    await scope.conversations.setArchived(ideas.id, true);

    final payload = await buildExport(scope);
    expect(payload['format'], ExportFormat.format);
    expect(payload['version'], ExportFormat.version);
    // JSON-serializable (what actually crosses the clipboard).
    final text = jsonEncode(payload);
    expect(text.length, greaterThan(100));

    // Clear everything, prove empty, then import.
    await scope.resetAll();
    expect(await scope.conversations.listRecent(), isEmpty);

    final decoded =
        (jsonDecode(text) as Map).map((k, v) => MapEntry('$k', v));
    final result = await importData(scope, decoded);
    expect(result.ok, isTrue);
    expect(result.importedConversations, 2);
    expect(result.importedMessages, 3);
    expect(result.skippedRows, 0);

    final titles = (await scope.conversations.listRecent(limit: 100))
        .map((c) => c.title)
        .toSet();
    // 'Ideas' is archived: active list holds only 'Trip'.
    expect(titles, contains('Trip'));
    final archived = await scope.conversations.listArchived(limit: 100);
    expect(archived.map((c) => c.title), contains('Ideas'));
    final pinned = (await scope.conversations.listRecent(limit: 100))
        .where((c) => c.isPinned)
        .map((c) => c.title);
    expect(pinned, contains('Trip'));

    // Existing data is never overwritten: add then re-import.
    await scope.conversations.create(title: 'Kept');
    final again = await importData(scope, decoded);
    expect(again.importedConversations, 2);
    final allTitles = (await scope.conversations.listRecent(limit: 100))
        .map((c) => c.title)
        .toList();
    expect(allTitles.where((t) => t == 'Trip').length, 2);
    expect(allTitles, contains('Kept'));
    await scope.close();
  });

  test('validation rejects bad payloads without writing', () async {
    final scope = await makeTestScope();
    for (final bad in [
      {'format': 'nope', 'version': 1, 'conversations': []},
      {'format': 'companion-export', 'version': 999, 'conversations': []},
      {'format': 'companion-export', 'version': 1},
      {'format': 'companion-export', 'version': 1, 'conversations': 'x'},
    ]) {
      final r = await importData(
          scope, bad.map((k, v) => MapEntry(k, v)));
      expect(r.ok, isFalse, reason: bad.toString());
      expect(r.importedConversations, 0);
    }
    expect(await scope.conversations.listRecent(), isEmpty);
    await scope.close();
  });

  test('invalid rows are skipped and counted', () async {
    final scope = await makeTestScope();
    final result = await importData(scope, {
      'format': ExportFormat.format,
      'version': ExportFormat.version,
      'conversations': [
        {'title': '  ', 'messages': []},
        'not-a-map',
        {
          'title': 'Good',
          'messages': [
            {'role': 'user', 'body': 'kept'},
            {'role': 'robot', 'body': 'bad role'},
            {'role': 'user'},
            'junk',
          ],
        },
      ],
    });
    expect(result.ok, isTrue);
    expect(result.importedConversations, 1);
    expect(result.importedMessages, 1);
    expect(result.skippedRows, 5);
    final convs = await scope.conversations.listRecent(limit: 10);
    expect(convs.single.title, 'Good');
    expect(await scope.messages.count(convs.single.id), 1);
    await scope.close();
  });
}

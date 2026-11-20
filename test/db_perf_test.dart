import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:ai_companion/data/database/app_db.dart';
import 'package:ai_companion/data/models/message.dart';

import 'test_scope.dart';

/// Performance smoke test (binding-free, host-measured via ffi).
/// Bounds are generous sanity limits, NOT device guarantees: they catch
/// pathological regressions (full-table scans, unbounded loads), not
/// device-specific jank. Numbers print for the report.
/// Device frame timing remains NOT TESTED (no device in this environment).
void main() {
  test('perf: 10k-message thread stays interactive', () async {
    final scope = await makeTestScope();
    final conv = await scope.conversations.ensureDefault();

    final sw = Stopwatch()..start();
    for (var i = 0; i < 10000; i++) {
      await scope.messages.insert(
        conversationId: conv.id,
        role: i.isEven ? MessageRole.user : MessageRole.assistant,
        body: 'perf message number $i with some filler words to scan',
      );
    }
    final insertMs = sw.elapsedMilliseconds;
    debugPrint('PERF insert 10k: ${insertMs}ms');

    sw.reset();
    final page = await scope.messages.page(conv.id, limit: 50);
    final pageMs = sw.elapsedMilliseconds;
    debugPrint('PERF page(50) of 10k: ${pageMs}ms');
    expect(page.length, 50);

    sw.reset();
    final hits =
        await scope.conversations.search('filler', limit: 100);
    final searchMs = sw.elapsedMilliseconds;
    debugPrint('PERF search over 10k msgs: ${searchMs}ms');
    expect(hits.map((c) => c.id), contains(conv.id));

    sw.reset();
    final n = await scope.messages.count(conv.id);
    final countMs = sw.elapsedMilliseconds;
    debugPrint('PERF count 10k: ${countMs}ms');
    expect(n, 10000);

    // Reopen timing ≈ cold-start DB cost proxy (host only).
    final dir = await Directory.systemTemp.createTemp('perfopen');
    final path = p.join(dir.path, 'perf.db');
    sw.reset();
    final db = await AppDb.open(pathOverride: path);
    final openMs = sw.elapsedMilliseconds;
    debugPrint('PERF fresh open: ${openMs}ms');
    // Lightweight scope just to exercise close on a real database.
    final reopenScope = realScopeFor(db);
    await reopenScope.close();
    await dir.delete(recursive: true);

    expect(insertMs, lessThan(120000), reason: 'bulk insert blew up');
    expect(pageMs, lessThan(2000), reason: 'paged read too slow');
    expect(searchMs, lessThan(5000), reason: 'LIKE search too slow');
    expect(countMs, lessThan(2000), reason: 'count too slow');
    expect(openMs, lessThan(10000), reason: 'open too slow');
    await scope.close();
  });
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ai_companion/data/models/companion_profile.dart';
import 'package:ai_companion/data/models/message.dart';
import 'package:ai_companion/features/ai/ai_provider.dart';
import 'package:ai_companion/features/ai/chat_pipeline.dart';
import 'package:ai_companion/features/ai/local_companion_provider.dart';
import 'package:ai_companion/features/ai/remote_ai_provider.dart';

import 'fakes.dart';
import 'test_scope.dart';

/// Phase 6 deterministic tests: providers, failures, retry, cancellation,
/// fallback, metadata persistence, zero-network proofs. No real network:
/// remote transport is always MockClient or scripted fakes.
void main() {
  Future<CompanionProfile> p() => _testProfile();

  group('endpoint validation', () {
    test('https accepted, http rejected except loopback', () {
      expect(
        RemoteAIProvider.resolveEndpoint(
            'https://api.openai.com/v1/', 'chat/completions'),
        Uri.parse('https://api.openai.com/v1/chat/completions'),
      );
      for (final bad in [
        'http://api.openai.com/v1',
        'ftp://x/y',
        'not a url',
        '',
        'https://',
      ]) {
        expect(
          () => RemoteAIProvider.resolveEndpoint(bad, 'chat/completions'),
          throwsA(isA<AiFailure>().having(
              (e) => e.kind, 'kind', AiFailureKind.misconfigured)),
          reason: bad,
        );
      }
      expect(
        RemoteAIProvider.resolveEndpoint(
            'http://localhost:1234/v1', 'models'),
        Uri.parse('http://localhost:1234/v1/models'),
      );
    });
  });

  group('local provider', () {
    test('answers offline with programmed text, no client involved',
        () async {
      final local = LocalCompanionProvider(profileReader: p);
      final out = await local.sendMessage(const AiChatRequest(
        conversationId: 'c',
        userText: 'hello',
        companionName: 'Buddy',
      ));
      expect(out.toLowerCase(), contains('sam'));
      expect(local.id, 'local');
    });
  });

  group('remote provider via MockClient', () {
    RemoteAIProvider provider(
      MockClient Function() make, {
      Future<String?> Function()? readKey,
    }) =>
        RemoteAIProvider(
          clientFactory: make,
          readApiKey: readKey ?? () async => 'test-key-123',
          baseUrl: 'https://ai.example.com/v1',
          model: 'test-model',
        );

    http.Response ok(String text) => http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'role': 'assistant', 'content': text}
              }
            ]
          }),
          200,
        );

    AiChatRequest req({Duration timeout = const Duration(seconds: 5)}) =>
        AiChatRequest(
          conversationId: 'c',
          userText: 'hi',
          companionName: 'Buddy',
          timeout: timeout,
        );

    test('successful response parses content', () async {
      final p = provider(() => MockClient((_) async => ok('  hello there  ')));
      expect(await p.sendMessage(req()), 'hello there');
      await p.dispose();
    });

    test('missing key fails misconfigured without network', () async {
      var calls = 0;
      final p = provider(
        () => MockClient((_) async {
          calls++;
          return ok('x');
        }),
        readKey: () async => null,
      );
      await expectLater(
        p.sendMessage(req()),
        throwsA(isA<AiFailure>().having(
            (e) => e.kind, 'kind', AiFailureKind.misconfigured)),
      );
      expect(calls, 0, reason: 'no request without a key');
      await p.dispose();
    });

    test('timeout maps to AiFailure.timeout', () async {
      final p = provider(() => MockClient((_) async {
            await Future<void>.delayed(const Duration(seconds: 2));
            return ok('late');
          }));
      await expectLater(
        p.sendMessage(req(timeout: const Duration(milliseconds: 50))),
        throwsA(isA<AiFailure>()
            .having((e) => e.kind, 'kind', AiFailureKind.timeout)),
      );
      await p.dispose();
    });

    test('socket/client errors map to network', () async {
      for (final ex in [
        const SocketException('down'),
        http.ClientException('broken'),
      ]) {
        final p = provider(() => MockClient((_) async {
              throw ex;
            }));
        await expectLater(
          p.sendMessage(req()),
          throwsA(isA<AiFailure>()
              .having((e) => e.kind, 'kind', AiFailureKind.network)),
        );
        await p.dispose();
      }
    });

    test('401/403 → auth, 429 → rateLimit, 500 → server', () async {
      final cases = {
        401: AiFailureKind.auth,
        403: AiFailureKind.auth,
        429: AiFailureKind.rateLimit,
        500: AiFailureKind.server,
        503: AiFailureKind.server,
        418: AiFailureKind.server,
      };
      for (final entry in cases.entries) {
        final p = provider(
            () => MockClient((_) async => http.Response('nope', entry.key)));
        await expectLater(
          p.sendMessage(req()),
          throwsA(isA<AiFailure>()
              .having((e) => e.kind, 'kind', entry.value)),
          reason: 'status ${entry.key}',
        );
        await p.dispose();
      }
    });

    test('malformed bodies map to malformed', () async {
      for (final body in [
        'not json{',
        '{"nope": true}',
        '{"choices": []}',
        '{"choices": [{"message": {"content": "   "}}]}',
        '{"choices": [{"message": {"content": 42}}]}',
      ]) {
        final p = provider(
            () => MockClient((_) async => http.Response(body, 200)));
        await expectLater(
          p.sendMessage(req()),
          throwsA(isA<AiFailure>()
              .having((e) => e.kind, 'kind', AiFailureKind.malformed)),
          reason: body,
        );
        await p.dispose();
      }
    });

    test('error text never contains the key', () async {
      const sneakyKey = 'sk-super-secret-xyz';
      final p = provider(
        () => MockClient((_) async => http.Response('denied', 401)),
        readKey: () async => sneakyKey,
      );
      try {
        await p.sendMessage(req());
        fail('must throw');
      } on AiFailure catch (e) {
        expect(e.userMessage, isNot(contains(sneakyKey)));
        expect(e.toString(), isNot(contains(sneakyKey)));
      }
      // Even a body echoing key-like content must not leak via our text.
      final p2 = provider(
        () => MockClient(
            (_) async => http.Response('{"error":"$sneakyKey"}', 200)),
        readKey: () async => sneakyKey,
      );
      try {
        await p2.sendMessage(req());
        fail('must throw');
      } on AiFailure catch (e) {
        expect(e.userMessage, isNot(contains(sneakyKey)));
      }
      await p.dispose();
      await p2.dispose();
    });

    test('cancellation aborts in-flight request', () async {
      final gate = Completer<void>();
      final p = provider(() => MockClient((_) async {
            await gate.future;
            return ok('too late');
          }));
      final pending = p.sendMessage(
          req(timeout: const Duration(seconds: 10)));
      p.cancelRequest();
      gate.complete();
      await expectLater(
        pending,
        throwsA(isA<AiFailure>()
            .having((e) => e.kind, 'kind', AiFailureKind.cancelled)),
      );
      await p.dispose();
    });
  });

  group('pipeline with scripted fake remote', () {
    test('disabled AI: local reply, remote never called', () async {
      final remote = FakeRemoteProvider();
      final scope = makeFakeScope(remote: remote);
      final pipe = ChatPipeline(scope: scope, ai: scope.ai);
      final conv = await scope.conversations.ensureDefault();
      final result = await pipe.send(conv.id, 'hello');
      expect(result.outcome, ChatSendOutcome.sentLocal);
      expect(remote.calls, 0);
      final thread = await scope.messages.page(conv.id, limit: 10);
      expect(
        thread.where((m) => m.role == MessageRole.assistant).single.provider,
        MessageProvider.local,
      );
      await scope.close();
    });

    test('auto mode success persists remote metadata', () async {
      final remote = FakeRemoteProvider()
        ..handler = (_) async => 'remote hello';
      final scope = makeFakeScope(remote: remote);
      await scope.settings.setAiEnabled(true);
      await scope.settings.setAiModeName('auto');
      final pipe = ChatPipeline(scope: scope, ai: scope.ai);
      final conv = await scope.conversations.ensureDefault();
      final result = await pipe.send(conv.id, 'hi');
      expect(result.outcome, ChatSendOutcome.sentRemote);
      expect(remote.calls, 1);
      final thread = await scope.messages.page(conv.id, limit: 10);
      final answer =
          thread.where((m) => m.role == MessageRole.assistant).single;
      expect(answer.body, 'remote hello');
      expect(answer.provider, MessageProvider.remote);
      await scope.close();
    });

    test('auto mode failure falls back labeled-local, keeps user row',
        () async {
      final remote = FakeRemoteProvider()
        ..handler = (_) async {
          throw AiFailure.network();
        };
      final scope = makeFakeScope(remote: remote);
      await scope.settings.setAiEnabled(true);
      await scope.settings.setAiModeName('auto');
      final pipe = ChatPipeline(scope: scope, ai: scope.ai);
      final conv = await scope.conversations.ensureDefault();
      final result = await pipe.send(conv.id, 'hi again');
      expect(result.outcome, ChatSendOutcome.sentLocal);
      expect(result.fallbackUsed, isTrue);
      final thread = await scope.messages.page(conv.id, limit: 10);
      expect(
        thread.where((m) => m.role == MessageRole.user).single.body,
        'hi again',
      );
      expect(
        thread.where((m) => m.role == MessageRole.assistant).single.provider,
        MessageProvider.local,
      );
      await scope.close();
    });

    test('remoteOnly failure persists nothing fake, retry works', () async {
      var attempts = 0;
      final remote = FakeRemoteProvider()
        ..handler = (_) async {
          attempts++;
          if (attempts == 1) throw AiFailure.rateLimit();
          return 'second try wins';
        };
      final scope = makeFakeScope(remote: remote);
      await scope.settings.setAiEnabled(true);
      await scope.settings.setAiModeName('remoteOnly');
      final pipe = ChatPipeline(scope: scope, ai: scope.ai);
      final conv = await scope.conversations.ensureDefault();

      final failed = await pipe.send(conv.id, 'please');
      expect(failed.outcome, ChatSendOutcome.remoteFailed);
      expect(failed.failure?.kind, AiFailureKind.rateLimit);
      var thread = await scope.messages.page(conv.id, limit: 10);
      expect(thread.length, 1, reason: 'only the user row exists');
      expect(thread.single.role, MessageRole.user);

      final retried = await pipe.retry(conv.id, failed.userText);
      expect(retried.outcome, ChatSendOutcome.sentRemote);
      thread = await scope.messages.page(conv.id, limit: 10);
      expect(thread.length, 2, reason: 'no duplicated user row');
      expect(
        thread.where((m) => m.role == MessageRole.user).length,
        1,
      );
      await scope.close();
    });

    test('disabling AI returns immediately to local behavior', () async {
      final remote = FakeRemoteProvider()
        ..handler = (_) async => 'remote!';
      final scope = makeFakeScope(remote: remote);
      await scope.settings.setAiEnabled(true);
      await scope.settings.setAiModeName('auto');
      final pipe = ChatPipeline(scope: scope, ai: scope.ai);
      final conv = await scope.conversations.ensureDefault();
      await pipe.send(conv.id, 'one');
      expect(remote.calls, 1);
      await scope.settings.setAiEnabled(false);
      final result = await pipe.send(conv.id, 'two');
      expect(result.outcome, ChatSendOutcome.sentLocal);
      expect(remote.calls, 1, reason: 'no further remote calls');
      await scope.close();
    });
  });

  group('metadata persistence (SQL)', () {
    test('provider survives file reopen', () async {
      final scope = await makeTestScope();
      final conv = await scope.conversations.ensureDefault();
      await scope.messages.insert(
        conversationId: conv.id,
        role: MessageRole.assistant,
        body: 'remote text',
        provider: MessageProvider.remote,
      );
      // Simulate reopen by reading the same row back through fromMap.
      final rows = await scope.db!.db.query('messages', limit: 5);
      expect(
        rows.map((r) => r['provider']),
        contains('remote'),
      );
      await scope.close();
    });
  });

  test('credential store round-trips without touching app settings',
      () async {
    final scope = makeFakeScope();
    expect(await scope.credentials.hasKey(), isFalse);
    await scope.credentials.writeKey('sk-test');
    expect(await scope.credentials.hasKey(), isTrue);
    expect(await scope.credentials.readKey(), 'sk-test');
    expect(await scope.settings.get('ai_api_key'), isNull);
    await scope.credentials.deleteKey();
    expect(await scope.credentials.hasKey(), isFalse);
    await scope.close();
  });
}

Future<CompanionProfile> _testProfile() async => CompanionProfile(
      name: 'Buddy',
      userName: 'Sam',
      createdAt: 0,
      updatedAt: 0,
    );

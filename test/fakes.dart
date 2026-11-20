import 'package:ai_companion/core/scope/app_scope.dart';
import 'package:ai_companion/core/utils/ids.dart';
import 'package:ai_companion/data/models/companion_profile.dart';
import 'package:ai_companion/data/models/conversation.dart';
import 'package:ai_companion/data/models/message.dart';
import 'package:ai_companion/data/repositories/companion_repository.dart';
import 'package:ai_companion/data/repositories/conversation_repository.dart';
import 'package:ai_companion/data/repositories/draft_repository.dart';
import 'package:ai_companion/data/repositories/message_repository.dart';
import 'package:ai_companion/data/repositories/settings_repository.dart';
import 'package:ai_companion/features/ai/ai_credentials.dart';
import 'package:ai_companion/features/ai/ai_provider.dart';
import 'package:ai_companion/features/ai/ai_runtime.dart';
import 'package:ai_companion/features/ai/local_companion_provider.dart';
import 'package:ai_companion/theme/app_themes.dart';

/// In-memory repository fakes. Widget tests MUST use these: ffi sqlite
/// deadlocks under TestWidgetsFlutterBinding in this environment (proven by
/// probe series 2026-09-23), while plain binding-free tests use real SQL.
/// Behavior mirrors the SQL implementations (ordering, blank-draft clearing,
/// defaults) so widget tests remain meaningful.
class FakeConversationRepository implements ConversationRepository {
  final Map<String, Conversation> store = {};
  int _seq = 0;

  /// Optional message-body lookup for [search] (wired by makeFakeScope).
  Future<List<Message>> Function(String conversationId)? bodiesForSearch;

  @override
  Future<Conversation> create({required String title}) async {
    final t = nowMs() + (_seq++);
    final c = Conversation(
        id: newId('conv'), title: title, createdAt: t, updatedAt: t);
    store[c.id] = c;
    return c;
  }

  @override
  Future<Conversation?> byId(String id) async => store[id];

  @override
  Future<List<Conversation>> listRecent(
      {int limit = 50, int offset = 0}) async {
    final items =
        store.values.where((c) => !c.isArchived).toList(growable: false)
          ..sort((a, b) {
            final pin = (b.isPinned ? 1 : 0) - (a.isPinned ? 1 : 0);
            return pin != 0 ? pin : b.updatedAt.compareTo(a.updatedAt);
          });
    return items.skip(offset).take(limit).toList();
  }

  @override
  Future<Conversation> ensureDefault() async {
    final existing = await listRecent(limit: 1);
    if (existing.isNotEmpty) return existing.first;
    return create(title: 'General');
  }

  @override
  Future<void> touch(
      {required String id,
      required String preview,
      required int messageCount}) async {
    final c = store[id];
    if (c == null) return;
    store[id] = Conversation(
      id: c.id,
      title: c.title,
      isArchived: c.isArchived,
      isPinned: c.isPinned,
      createdAt: c.createdAt,
      updatedAt: nowMs(),
      lastMessagePreview: preview,
      messageCount: messageCount,
      summary: c.summary,
    );
  }

  @override
  Future<void> rename(String id, String title) async {
    final c = store[id];
    if (c == null) return;
    store[id] = Conversation(
      id: c.id,
      title: title,
      isArchived: c.isArchived,
      isPinned: c.isPinned,
      createdAt: c.createdAt,
      updatedAt: nowMs(),
      lastMessagePreview: c.lastMessagePreview,
      messageCount: c.messageCount,
      summary: c.summary,
    );
  }

  @override
  Future<void> delete(String id) async {
    store.remove(id);
  }

  @override
  Future<void> clearAll() async {
    store.clear();
  }

  @override
  Future<void> setPinned(String id, bool pinned) async {
    final c = store[id];
    if (c == null) return;
    store[id] = Conversation(
      id: c.id,
      title: c.title,
      isArchived: c.isArchived,
      isPinned: pinned,
      createdAt: c.createdAt,
      updatedAt: nowMs(),
      lastMessagePreview: c.lastMessagePreview,
      messageCount: c.messageCount,
      summary: c.summary,
    );
  }

  @override
  Future<void> setArchived(String id, bool archived) async {
    final c = store[id];
    if (c == null) return;
    store[id] = Conversation(
      id: c.id,
      title: c.title,
      isArchived: archived,
      isPinned: c.isPinned,
      createdAt: c.createdAt,
      updatedAt: nowMs(),
      lastMessagePreview: c.lastMessagePreview,
      messageCount: c.messageCount,
      summary: c.summary,
    );
  }

  @override
  Future<List<Conversation>> listArchived(
      {int limit = 50, int offset = 0}) async {
    final items = store.values
        .where((c) => c.isArchived)
        .toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items.skip(offset).take(limit).toList();
  }

  @override
  Future<List<Conversation>> search(String query,
      {bool archived = false, int limit = 100}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return archived
          ? listArchived(limit: limit)
          : listRecent(limit: limit);
    }
    final out = <Conversation>[];
    for (final c in store.values) {
      if (c.isArchived != archived) continue;
      if (c.title.toLowerCase().contains(q) ||
          (c.lastMessagePreview ?? '').toLowerCase().contains(q)) {
        out.add(c);
        continue;
      }
      final bodies = await bodiesForSearch?.call(c.id) ?? const [];
      if (bodies.any((m) => m.body.toLowerCase().contains(q))) {
        out.add(c);
      }
    }
    out.sort((a, b) {
      final pin = (b.isPinned ? 1 : 0) - (a.isPinned ? 1 : 0);
      return pin != 0 ? pin : b.updatedAt.compareTo(a.updatedAt);
    });
    return out.take(limit).toList();
  }
}

class FakeMessageRepository implements MessageRepository {
  final List<Message> store = [];
  int _seq = 0;

  @override
  Future<Message> insert({
    required String conversationId,
    required MessageRole role,
    required String body,
    MessageStatus status = MessageStatus.sent,
    String? requestId,
    MessageProvider? provider,
    String? error,
  }) async {
    final t = nowMs() + (_seq++);
    final m = Message(
      id: newId('msg'),
      conversationId: conversationId,
      role: role,
      body: body,
      status: status,
      createdAt: t,
      updatedAt: t,
      requestId: requestId,
      provider: provider,
      error: error,
    );
    store.add(m);
    return m;
  }

  List<Message> _thread(String conversationId) {
    final items =
        store.where((m) => m.conversationId == conversationId).toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  @override
  Future<List<Message>> page(String conversationId,
      {int limit = 50, int offset = 0}) async {
    return _thread(conversationId).skip(offset).take(limit).toList();
  }

  @override
  Future<int> count(String conversationId) async =>
      _thread(conversationId).length;

  @override
  Future<void> updateStatus(String id, MessageStatus status) async {
    final i = store.indexWhere((m) => m.id == id);
    if (i < 0) return;
    final m = store[i];
    store[i] = Message(
      id: m.id,
      conversationId: m.conversationId,
      role: m.role,
      body: m.body,
      status: status,
      createdAt: m.createdAt,
      updatedAt: nowMs(),
      requestId: m.requestId,
      provider: m.provider,
      error: m.error,
    );
  }

  @override
  Future<void> delete(String id) async {
    store.removeWhere((m) => m.id == id);
  }

  void clearConversation(String conversationId) {
    store.removeWhere((m) => m.conversationId == conversationId);
  }

  void clearAll() => store.clear();
}

class FakeDraftRepository implements DraftRepository {
  final Map<String, String> store = {};

  @override
  Future<String?> get(String conversationId) async =>
      store[conversationId];

  @override
  Future<void> set(String conversationId, String body) async {
    if (body.trim().isEmpty) {
      store.remove(conversationId);
      return;
    }
    store[conversationId] = body;
  }

  @override
  Future<void> clear(String conversationId) async {
    store.remove(conversationId);
  }

  void clearAll() => store.clear();
}

class FakeSettingsRepository implements SettingsRepository {
  final Map<String, String> store = {};

  @override
  Future<String?> get(String key) async => store[key];

  @override
  Future<void> set(String key, String value) async {
    store[key] = value;
  }

  @override
  Future<bool> isOnboardingDone() async =>
      store['onboarding_done'] == '1';

  @override
  Future<void> setOnboardingDone(bool done) async {
    store['onboarding_done'] = done ? '1' : '0';
  }

  @override
  Future<AppThemeMode> themeMode() async {
    return switch (store['theme_mode']) {
      'light' => AppThemeMode.light,
      'dark' => AppThemeMode.dark,
      'oled' => AppThemeMode.oled,
      _ => AppThemeMode.system,
    };
  }

  @override
  Future<void> setThemeMode(AppThemeMode mode) async {
    store['theme_mode'] = mode.name;
  }

  Future<bool> _flag(String key, bool fallback) async {
    final raw = store[key];
    if (raw == null) return fallback;
    return raw == '1';
  }

  @override
  Future<bool> autoReply() => _flag('companion_auto_reply', true);
  @override
  Future<void> setAutoReply(bool v) async {
    store['companion_auto_reply'] = v ? '1' : '0';
  }

  @override
  Future<bool> dailyGreeting() => _flag('daily_greeting', true);
  @override
  Future<void> setDailyGreeting(bool v) async {
    store['daily_greeting'] = v ? '1' : '0';
  }

  @override
  Future<bool> dailyQuestion() => _flag('daily_question', true);
  @override
  Future<void> setDailyQuestion(bool v) async {
    store['daily_question'] = v ? '1' : '0';
  }

  @override
  Future<double> textScale() async {
    final v = double.tryParse(store['text_scale'] ?? '');
    if (v == null) return 1.0;
    return v.clamp(0.8, 1.3);
  }

  @override
  Future<void> setTextScale(double v) async {
    store['text_scale'] = v.clamp(0.8, 1.3).toString();
  }

  @override
  Future<bool> reducedMotion() => _flag('reduced_motion', false);
  @override
  Future<void> setReducedMotion(bool v) async {
    store['reduced_motion'] = v ? '1' : '0';
  }

  @override
  Future<bool> aiEnabled() => _flag('ai_enabled', false);
  @override
  Future<void> setAiEnabled(bool v) async {
    store['ai_enabled'] = v ? '1' : '0';
  }

  @override
  Future<String> aiModeName() async =>
      store['ai_mode'] ?? AiModeDefaults.localOnly;
  @override
  Future<void> setAiModeName(String v) async {
    store['ai_mode'] = v;
  }

  @override
  Future<String> aiBaseUrl() async =>
      store['ai_base_url'] ?? AiModeDefaults.baseUrl;
  @override
  Future<void> setAiBaseUrl(String v) async {
    store['ai_base_url'] = v;
  }

  @override
  Future<String> aiModel() async =>
      store['ai_model'] ?? AiModeDefaults.model;
  @override
  Future<void> setAiModel(String v) async {
    store['ai_model'] = v;
  }

  @override
  Future<String> aiProviderId() async =>
      store['ai_provider_id'] ?? AiModeDefaults.providerId;
  @override
  Future<void> setAiProviderId(String v) async {
    store['ai_provider_id'] = v;
  }

  void clearAll() => store.clear();
}

class FakeCompanionRepository implements CompanionRepository {
  CompanionProfile? current;

  @override
  Future<CompanionProfile> getOrCreate() async {
    if (current != null) return current!;
    final t = nowMs();
    current = CompanionProfile(createdAt: t, updatedAt: t);
    return current!;
  }

  @override
  Future<CompanionProfile> save(CompanionProfile profile) async {
    current = profile.copyWith(
        version: profile.version + 1, updatedAt: nowMs());
    return current!;
  }

  @override
  Future<CompanionProfile> resetToDefaults() async {
    final t = nowMs();
    current = CompanionProfile(createdAt: t, updatedAt: t);
    return current!;
  }
}

/// In-memory API-key store for tests. Production uses platform secure
/// storage; this fake proves credential flows without touching it.
class FakeAiCredentialStore implements AiCredentialStore {
  String? key;
  int reads = 0;
  int writes = 0;

  @override
  Future<String?> readKey() async {
    reads++;
    return key;
  }

  @override
  Future<void> writeKey(String k) async {
    writes++;
    key = k;
  }

  @override
  Future<void> deleteKey() async {
    key = null;
  }

  @override
  Future<bool> hasKey() async => key != null && key!.isNotEmpty;
}

/// Scripted remote backend for pipeline/widget tests. [handler] decides the
/// outcome per call; [calls] counts invocations (zero-network proofs assert
/// this stays 0). Never performs I/O.
class FakeRemoteProvider implements AiCompanionProvider {
  @override
  String get id => 'fake-remote';

  @override
  String get displayName => 'Fake remote';

  int calls = 0;
  bool cancelCalled = false;
  Future<String> Function(AiChatRequest request)? handler;

  @override
  Future<String> sendMessage(AiChatRequest request) async {
    calls++;
    final h = handler;
    if (h != null) return h(request);
    throw AiFailure.network();
  }

  @override
  void cancelRequest() {
    cancelCalled = true;
  }

  @override
  Future<void> dispose() async {}
}

/// Widget-test scope: zero sqlite, zero ffi, zero network. Each test gets a
/// fresh scope. Pass [remote] to script AI-enabled behavior; omit it and
/// [AiRuntime.resolveRemote] still builds only when settings enable AI.
AppScopeData makeFakeScope({
  FakeRemoteProvider? remote,
  FakeAiCredentialStore? credentials,
}) {
  final convs = FakeConversationRepository();
  final msgs = FakeMessageRepository();
  final drafts = FakeDraftRepository();
  final settings = FakeSettingsRepository();
  final companion = FakeCompanionRepository();
  final creds = credentials ?? FakeAiCredentialStore();
  final fakeRemote = remote ?? FakeRemoteProvider();
  convs.bodiesForSearch =
      (id) => msgs.page(id, limit: 100000);
  return AppScopeData(
    conversations: convs,
    messages: msgs,
    drafts: drafts,
    settings: settings,
    companion: companion,
    resetAll: () async {
      convs.clearAll();
      msgs.clearAll();
      drafts.clearAll();
      settings.clearAll();
      await companion.resetToDefaults();
    },
    close: () async {},
    credentials: creds,
    ai: AiRuntime(
      local: LocalCompanionProvider(
        profileReader: () => companion.getOrCreate(),
      ),
      credentials: creds,
      remoteFactory: (_) => fakeRemote,
    ),
  );
}

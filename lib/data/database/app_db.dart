import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// SQLite database owner. V1 schema mirrors docs/08-database-schema.md.
/// - WAL mode, foreign keys on, versioned, backward-compatible migrations.
/// - No queries run from widgets; only repositories touch [db].
class AppDb {
  static const String fileName = 'ai_companion.db';

  /// v2 adds nullable `provider`/`error` columns to messages (Phase 6).
  static const int schemaVersion = 2;

  final Database db;
  AppDb._(this.db);

  /// Opens (creating/migrating as needed). [pathOverride] is a test hook
  /// (e.g. [inMemoryDatabasePath]) so host tests never touch the device FS.
  static Future<AppDb> open({String? pathOverride}) async {
    final path = pathOverride ?? p.join(await getDatabasesPath(), fileName);
    final db = await openDatabase(
      path,
      version: schemaVersion,
      onCreate: (db, version) => _createV1(db),
      onUpgrade: (db, oldVersion, newVersion) =>
          _migrate(db, oldVersion, newVersion),
      onConfigure: (db) async {
        // WAL keeps readers responsive during writes (chat scroll + insert).
        await db.rawQuery('PRAGMA journal_mode=WAL');
        // FKs off by default in SQLite; required for CASCADE message delete.
        await db.rawQuery('PRAGMA foreign_keys=ON');
      },
    );
    return AppDb._(db);
  }

  Future<void> close() => db.close();

  /// PRAGMA user_version as set by openDatabase (== [schemaVersion]).
  Future<int> userVersion() async {
    final rows = await db.rawQuery('PRAGMA user_version');
    return (rows.first['user_version']! as int);
  }

  /// Wipes every user table (conversations, messages, drafts, memories,
  /// schedules, journal, settings, profiles). Schema + version survive.
  /// Used by Reset in Privacy settings; double-confirmed in UI.
  Future<void> clearAllData() async {
    await db.transaction((txn) async {
      for (final t in [
        'messages',
        'conversations',
        'kv_drafts',
        'memories',
        'notification_schedules',
        'journal_entries',
        'app_settings',
        'user_profile',
        'companion_profile',
      ]) {
        await txn.delete(t);
      }
    });
  }

  /// Full v1 DDL. Keep in sync with docs/08-database-schema.md.
  static Future<void> _createV1(Database db) async {
    final b = db.batch();
    b.execute('''
CREATE TABLE user_profile(
  id TEXT PRIMARY KEY,
  displayName TEXT,
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL)''');
    b.execute('''
CREATE TABLE companion_profile(
  id TEXT PRIMARY KEY DEFAULT 'default',
  name TEXT NOT NULL DEFAULT 'Companion',
  avatarRef TEXT,
  axesJson TEXT NOT NULL DEFAULT '{}',
  humor INTEGER DEFAULT 50,
  emoji INTEGER DEFAULT 50,
  respLength TEXT DEFAULT 'medium',
  interests TEXT DEFAULT '[]',
  avoidTopics TEXT DEFAULT '[]',
  userName TEXT,
  commPrefs TEXT DEFAULT '{}',
  version INTEGER NOT NULL DEFAULT 1,
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL)''');
    b.execute('''
CREATE TABLE conversations(
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  isArchived INTEGER NOT NULL DEFAULT 0,
  isPinned INTEGER NOT NULL DEFAULT 0,
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL,
  lastMessagePreview TEXT,
  messageCount INTEGER NOT NULL DEFAULT 0,
  summary TEXT)''');
    b.execute(
      'CREATE INDEX idx_conv_updated ON conversations'
      '(isArchived, isPinned DESC, updatedAt DESC)',
    );
    b.execute('''
CREATE TABLE messages(
  id TEXT PRIMARY KEY,
  conversationId TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK(role IN ('user','assistant','system')),
  body TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'sent' CHECK(status IN
    ('sending','sent','failed_retryable','failed_final',
     'queued_offline','streaming','interrupted')),
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL,
  requestId TEXT,
  provider TEXT CHECK(provider IN ('local','remote')),
  error TEXT)''');
    b.execute(
      'CREATE INDEX idx_msg_conv ON messages(conversationId, createdAt)',
    );
    b.execute('''
CREATE TABLE memories(
  id TEXT PRIMARY KEY,
  kind TEXT NOT NULL,
  key TEXT NOT NULL,
  value TEXT NOT NULL,
  source TEXT NOT NULL DEFAULT 'user',
  confidence REAL DEFAULT 1.0,
  sensitivity TEXT DEFAULT 'normal',
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL,
  supersededBy TEXT)''');
    b.execute('CREATE INDEX idx_mem_key ON memories(kind, key)');
    b.execute('''
CREATE TABLE notification_schedules(
  id TEXT PRIMARY KEY,
  kind TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  cronOrTime TEXT NOT NULL,
  timezone TEXT NOT NULL,
  quietStart TEXT,
  quietEnd TEXT,
  enabled INTEGER NOT NULL DEFAULT 1,
  lastFiredAt INTEGER,
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL)''');
    b.execute('''
CREATE TABLE journal_entries(
  id TEXT PRIMARY KEY,
  mood TEXT,
  note TEXT NOT NULL DEFAULT '',
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL)''');
    b.execute('''
CREATE TABLE app_settings(
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updatedAt INTEGER NOT NULL)''');
    b.execute('''
CREATE TABLE kv_drafts(
  conversationId TEXT PRIMARY KEY,
  body TEXT NOT NULL,
  updatedAt INTEGER NOT NULL)''');
    // FTS5 + vector tables reserved post-MVP (docs/08); added via migration.
    await b.commit(noResult: true);
  }

  /// Backward-compatible migrations. Each block runs once when
  /// `oldVersion` is below it. Never destructive; never drops data.
  static Future<void> _migrate(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 1) {
      await _createV1(db);
    }
    if (oldVersion < 2) {
      // Phase 6: assistant-source metadata. Nullable → old rows keep
      // working (read back as local-era messages).
      await db.execute(
          'ALTER TABLE messages ADD COLUMN provider TEXT '
          "CHECK(provider IN ('local','remote'))");
      await db.execute('ALTER TABLE messages ADD COLUMN error TEXT');
    }
  }
}

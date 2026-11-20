import 'package:sqflite/sqflite.dart';

import '../../core/utils/ids.dart';
import '../database/app_db.dart';
import '../models/companion_profile.dart';

/// Companion profile contract. Exactly one row (`id = 'default'`).
abstract class CompanionRepository {
  Future<CompanionProfile> getOrCreate();
  Future<CompanionProfile> save(CompanionProfile profile);
  Future<CompanionProfile> resetToDefaults();
}

class SqlCompanionRepository implements CompanionRepository {
  final AppDb appDb;
  SqlCompanionRepository(this.appDb);

  @override
  Future<CompanionProfile> getOrCreate() async {
    final rows = await appDb.db.query(
      'companion_profile',
      where: 'id = ?',
      whereArgs: [CompanionProfile.defaultId],
      limit: 1,
    );
    if (rows.isNotEmpty) return CompanionProfile.fromMap(rows.first);
    final t = nowMs();
    final fresh = CompanionProfile(createdAt: t, updatedAt: t);
    await appDb.db.insert('companion_profile', fresh.toMap());
    return fresh;
  }

  @override
  Future<CompanionProfile> save(CompanionProfile profile) async {
    final next = profile.copyWith(
      version: profile.version + 1,
      updatedAt: nowMs(),
    );
    await appDb.db.insert(
      'companion_profile',
      next.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return next;
  }

  @override
  Future<CompanionProfile> resetToDefaults() async {
    final t = nowMs();
    final fresh = CompanionProfile(createdAt: t, updatedAt: t);
    await appDb.db.insert(
      'companion_profile',
      fresh.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return fresh;
  }
}

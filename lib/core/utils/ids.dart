import 'dart:math';

import 'package:flutter/foundation.dart';

/// Local ID generator (no new dependencies).
/// Monotonic-ish unique ids for local-only rows; sync (P-future) will
/// replace/augment with server ids. Format keeps lexical order ~ creation.
String newId([String prefix = 'id']) {
  final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final r = Random.secure().nextInt(1 << 32).toRadixString(36);
  return '${prefix}_$t$r';
}

/// Milliseconds-since-epoch clock. Centralized so tests can reason about
/// ordering without importing clock packages (P2 keeps zero extra deps).
int nowMs() => DateTime.now().millisecondsSinceEpoch;

@visibleForTesting
int fixedMs(int value) => value;

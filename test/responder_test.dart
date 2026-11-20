import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_companion/features/activities/activities.dart';
import 'package:ai_companion/features/companion/local_responder.dart';
import 'package:ai_companion/features/daily/daily_content.dart';

/// P3 pure-logic tests: responder, activities registry, daily content.
/// No database, no widgets — deterministic via seeded Random.
void main() {
  LocalResponder r() =>
      LocalResponder(companionName: 'Buddy', userName: 'Sam');

  test('greeting rule answers with names', () {
    final out = r().respond('hello there', random: Random(1));
    expect(out.toLowerCase(), contains('sam'));
  });

  test('identity answers honestly: on-device, prewritten, no AI', () {
    final out = r().respond('who are you?', random: Random(1));
    expect(out, contains('Buddy'));
    expect(out.toLowerCase(), contains('prewritten'));
    expect(out.toLowerCase(), contains('no ai'));
  });

  test('help lists real local capabilities', () {
    final out = r().respond('help me', random: Random(1));
    expect(out.toLowerCase(), contains('activit'));
    expect(out.toLowerCase(), contains('device'));
  });

  test('distress gets supportive non-clinical reply, no diagnosis', () {
    final out = r().respond('i feel so stressed today', random: Random(1));
    expect(out.toLowerCase(), contains('journal'));
    expect(out.toLowerCase(), isNot(contains('diagnos')));
  });

  test('fallback never claims AI/consciousness/memory', () {
    final resp = LocalResponder(companionName: 'Buddy');
    const banned = [
      'as an ai', 'ai model', 'conscious', 'i feel ',
      'i remember', 'neural', 'gpt', 'language model',
    ];
    for (var i = 0; i < 30; i++) {
      final out = resp.respond('xqzt blorp $i', random: Random(i)).toLowerCase();
      for (final b in banned) {
        expect(out, isNot(contains(b)), reason: 'banned phrase "$b" in: $out');
      }
    }
  });

  test('seeded random is deterministic', () {
    final a = r().respond('tell me a joke', random: Random(7));
    final b = r().respond('tell me a joke', random: Random(7));
    expect(a, b);
  });

  test('time answer uses device clock format', () {
    final out = r().respond('what time is it?', random: Random(1));
    expect(out, contains('device says'));
  });

  test('activities registry: 7 built-ins, all non-empty, lookup works', () {
    expect(builtInActivities.length, 7);
    for (final a in builtInActivities) {
      expect(a.prompts, isNotEmpty, reason: a.id);
    }
    expect(activityById('trivia')!.title, contains('Trivia'));
    expect(activityById('nope'), isNull);
  });

  test('daily prompt is calendar-deterministic', () {
    final d = DateTime(2026, 9, 23);
    expect(
      activityById('daily_prompt')!.promptFor(d),
      activityById('daily_prompt')!.promptFor(d),
    );
  });

  test('daily greeting respects time of day + name', () {
    expect(DailyContent.greeting(DateTime(2026, 1, 1, 9), 'Sam'),
        'Good morning, Sam!');
    expect(DailyContent.greeting(DateTime(2026, 1, 1, 15), null),
        'Good afternoon!');
    expect(DailyContent.greeting(DateTime(2026, 1, 1, 21), '  '),
        'Good evening!');
  });

  test('daily question/reflection deterministic per date', () {
    final d = DateTime(2026, 9, 23);
    expect(DailyContent.questionFor(d), DailyContent.questionFor(d));
    expect(DailyContent.reflectionFor(d), DailyContent.reflectionFor(d));
    // Leap day must not crash.
    DailyContent.questionFor(DateTime(2028, 2, 29));
    DailyContent.reflectionFor(DateTime(2028, 2, 29));
  });

  test('instant fun stays in range', () {
    final rand = Random(3);
    for (var i = 0; i < 20; i++) {
      expect(InstantFun.coinFlip(rand), contains(RegExp('HEADS|TAILS')));
      final roll = InstantFun.diceRoll(rand);
      final n = int.parse(RegExp(r'\d+').firstMatch(roll)!.group(0)!);
      expect(n, inInclusiveRange(1, 6));
    }
  });
}

import '../activities/activities.dart';

/// In-app daily companion content. Pure date math — no notifications plugin,
/// no background work, no network. The Home card shows today's content;
/// a new day automatically shows new content.
class DailyContent {
  /// "Good morning/afternoon/evening[, name]". Hour boundaries are local time.
  static String greeting(DateTime now, String? userName) {
    final part = now.hour < 12
        ? 'morning'
        : now.hour < 18
            ? 'afternoon'
            : 'evening';
    final who = (userName != null && userName.trim().isNotEmpty)
        ? ', ${userName.trim()}'
        : '';
    return 'Good $part$who!';
  }

  /// Deterministic daily question (calendar-indexed, leap-safe).
  static String questionFor(DateTime date) {
    const qs = [
      'What is one thing you want to get out of today?',
      'Who is someone you appreciate right now?',
      'What is something small you are grateful for?',
      'What would make today feel complete?',
      'What is on your mind this morning?',
      'What is one thing you can do today for future-you?',
      'What made you smile recently?',
    ];
    return qs[_dayIndex(date, qs.length)];
  }

  /// Deterministic daily reflection (evening-oriented, shown any time).
  static String reflectionFor(DateTime date) {
    const rs = [
      'What went well today, even in a small way?',
      'What did you learn about yourself today?',
      'What is one thing you would do the same tomorrow?',
      'What deserves a little more of your attention?',
      'End the day with one honest sentence about how it felt.',
    ];
    return rs[_dayIndex(date, rs.length)];
  }

  /// Convenience: today's activity prompt (delegates to the registry).
  static String activityPromptFor(DateTime date) =>
      activityById('daily_prompt')!.promptFor(date);

  static int _dayIndex(DateTime date, int count) {
    final dayOfYear =
        date.difference(DateTime(date.year, 1, 1)).inDays;
    return (date.year * 1000 + dayOfYear) % count;
  }
}

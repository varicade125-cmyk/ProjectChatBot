import 'dart:math';

/// Local, deterministic companion responder. NOT AI: every reply comes from
/// prewritten sets selected by keyword rules, optionally shuffled with an
/// injected [Random] (seeded in tests for determinism).
///
/// Honesty contract (docs/13):
/// - Never claims AI generation, consciousness, memory, or feelings.
/// - Never diagnoses, never guilt-trips, never pressures continued use.
/// - Replies are short, friendly, and context-independent.
class LocalResponder {
  final String companionName;
  final String? userName;
  final String verbosity;

  LocalResponder({
    required this.companionName,
    this.userName,
    this.verbosity = 'medium',
  });

  String _you() => (userName != null && userName!.trim().isNotEmpty)
      ? ', ${userName!.trim()}'
      : '';

  String respond(String input, {Random? random}) {
    final r = random ?? Random();
    final text = input.toLowerCase();

    if (text.contains('your name') || text.contains('who are you')) {
      return "I'm $companionName, your on-device companion. I keep your notes "
          'here on your phone and answer with prewritten replies — no AI, '
          'no internet. What would you like to do?';
    }
    if (_hasWord(
        text, ['hello', 'hi', 'hey', 'yo', 'sup', 'morning', 'evening'])) {
      return _pick(_greetings(), r);
    }
    if (_hasAny(text, ['how are you', 'how r u', 'how do you feel'])) {
      return 'Running smoothly on your device, thanks for asking! '
          'How are you doing${_you()}?';
    }
    if (_hasAny(text, ['thank', 'thanks', 'thx'])) {
      return "You're welcome${_you()}! Anything else on your mind?";
    }
    if (_hasAny(text, ['bye', 'goodbye', 'good night', 'see you', 'gtg'])) {
      return 'Goodbye${_you()}! Your notes stay saved here for next time.';
    }
    if (_hasAny(text, ['help', 'what can you do', 'features', 'how does this work'])) {
      return _help();
    }
    if (text.contains('joke') || text.contains('funny')) {
      return _pick(_jokes, r);
    }
    if (text.contains('trivia')) {
      return 'Open an activity from Home and pick Trivia — I keep score-free '
          'questions with answers included. No pressure, just fun.';
    }
    if (_hasAny(text, ['sad', 'tired', 'stressed', 'anxious', 'lonely', 'down'])) {
      return 'That sounds tough, and it makes sense to feel that way. '
          "I'm just prewritten replies, so I can't truly understand — but "
          'jotting it in your journal here can help, and reaching out to '
          'someone you trust is always a good step. Want a calm reflection '
          'prompt?';
    }
    if (_hasAny(text, ['happy', 'excited', 'great news', 'awesome', 'amazing'])) {
      return "That's wonderful${_you()}! Want to jot down what made it great "
          'so you remember it later?';
    }
    if (_hasAny(text, ['time', 'date', 'day is it', 'clock'])) {
      return _timeAnswer();
    }
    if (_hasAny(text, ['remember', 'remind'])) {
      return 'I keep your notes saved on this device. If you want a daily '
          'nudge, turn on the daily greeting in Settings — it never leaves '
          'your phone.';
    }
    if (_hasAny(text, ['love you', 'like you', 'best friend'])) {
      return "That's kind of you to say! I'm a simple programmed companion, "
          "so I'll just keep being reliably here for your notes and routines.";
    }
    return _pick(_fallbacks(), r);
  }

  List<String> _greetings() {
    final you = _you();
    final base = [
      'Hello$you! Good to see you. What\'s on your mind today?',
      'Hey$you! Pull up a chair — want to talk, journal, or try an activity?',
    ];
    if (verbosity == 'short') return [base.first];
    return [
      ...base,
      'Hi$you! I\'m $companionName, running entirely on your device. '
          'We can chat, you can journal, or we can open a fun activity from Home.',
    ];
  }

  List<String> _fallbacks() {
    final you = _you();
    final base = [
      'Noted$you — I saved that here. Tell me more, or pick an activity from Home.',
      'Got it$you. I keep everything on this device. What else is on your mind?',
      'Thanks for sharing that$you. Want to turn it into a journal entry?',
    ];
    if (verbosity == 'short') return [base.first];
    return [
      ...base,
      'Interesting$you. I only know prewritten replies, so I may miss nuance — '
          'but your words are safely stored. Shall we try a reflection prompt?',
      'I hear you$you. If it helps, the Activities on Home have starters, '
          'trivia, and would-you-rather questions to explore.',
    ];
  }

  String _help() {
    final short = 'I can: keep your notes, offer activities (trivia, '
        'would-you-rather, journaling prompts), and show a daily greeting. '
        'Everything stays on your device.';
    if (verbosity == 'short') return short;
    return '$short Try the Activities on Home, or just keep writing here — '
        'I save every entry. Settings lets you change my name, look, and habits.';
  }

  String _timeAnswer() {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return 'Your device says $hh:$mm on ${days[now.weekday - 1]}, '
        '${months[now.month - 1]} ${now.day}.';
  }

  bool _hasAny(String text, List<String> keys) =>
      keys.any(text.contains);

  /// Whole-word match for short tokens ('hi' must not match 'this',
  /// 'yo' must not match 'you'). Longer phrases keep substring matching.
  bool _hasWord(String text, List<String> words) {
    final pattern =
        words.map(RegExp.escape).join('|');
    return RegExp('\\b($pattern)\\b').hasMatch(text);
  }

  String _pick(List<String> options, Random r) =>
      options[r.nextInt(options.length)];

  static const List<String> _jokes = [
    'Why do programmers prefer dark mode? Because light attracts bugs! '
        '(Prewritten joke #1 — I only know a few.)',
    'I told my calendar a joke once. It was dated. (That\'s all of them, '
        'almost — ask again for another.)',
    'Why did the notebook stay calm? It had plenty of pages to process '
        'things. Feel free to use yours here too.',
  ];
}

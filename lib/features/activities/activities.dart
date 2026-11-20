import 'dart:math';

/// Offline activity model. Each activity is a named set of prewritten
/// prompts; some offer instant `play` results (coin/dice). Adding a new
/// activity = appending one entry to [builtInActivities]. No network, no AI.
class Activity {
  final String id;
  final String title;
  final String description;
  final List<String> prompts;

  const Activity({
    required this.id,
    required this.title,
    required this.description,
    required this.prompts,
  });

  /// Deterministic pick for "prompt of the moment" screens.
  String promptFor(DateTime date, {Random? random}) {
    if (random != null) return prompts[random.nextInt(prompts.length)];
    final seed = date.year * 1000 + _dayOfYear(date);
    return prompts[seed % prompts.length];
  }
}

int _dayOfYear(DateTime d) =>
    d.difference(DateTime(d.year, 1, 1)).inDays;

const List<Activity> builtInActivities = [
  Activity(
    id: 'starters',
    title: 'Conversation starters',
    description: 'Easy openings when you are not sure what to write.',
    prompts: [
      'What was the best small moment of your day so far?',
      'If today had a title, what would it be?',
      'What is something you are looking forward to this week?',
      'Describe your current mood as weather. Why that forecast?',
      'What is one thing you learned recently, big or small?',
      'If you had an extra hour today, how would you spend it?',
    ],
  ),
  Activity(
    id: 'trivia',
    title: 'Trivia (self-checked)',
    description: 'Questions with answers included — check yourself, no score kept.',
    prompts: [
      'Q: How many legs does a spider have? A: Eight.',
      'Q: What planet is known as the Red Planet? A: Mars.',
      'Q: How many days are in a leap year? A: 366.',
      'Q: What is the largest ocean on Earth? A: The Pacific Ocean.',
      'Q: Which animal is the tallest in the world? A: The giraffe.',
      'Q: How many colors are in a rainbow? A: Seven.',
    ],
  ),
  Activity(
    id: 'would_you_rather',
    title: 'Would you rather',
    description: 'Playful either-or questions. There are no wrong answers.',
    prompts: [
      'Would you rather have the morning off or the afternoon off?',
      'Would you rather explore a new city or revisit a favorite place?',
      'Would you rather cook a new recipe or order your favorite meal?',
      'Would you rather read a book or listen to it?',
      'Would you rather take a long walk or a short nap?',
      'Would you rather plan everything or improvise the day?',
    ],
  ),
  Activity(
    id: 'journal',
    title: 'Journaling prompts',
    description: 'Write as much or as little as you like. It all stays here.',
    prompts: [
      'Write about today in three sentences.',
      'What is weighing on your mind right now? Put it into words.',
      'List three things that went okay today.',
      'Write a short note to your future self.',
      'What is one thing you want to remember about this week?',
    ],
  ),
  Activity(
    id: 'brainstorm',
    title: 'Brainstorming prompts',
    description: 'Loose creative sparks. Quantity over quality.',
    prompts: [
      'List ten uses for an empty jar.',
      'Invent a holiday and describe how people celebrate it.',
      'Name five small ways to make an ordinary Tuesday better.',
      'What would a club for your hobby do at its first meeting?',
      'Combine two random objects and invent what the result does.',
    ],
  ),
  Activity(
    id: 'reflection',
    title: 'Reflection prompts',
    description: 'Slow down for a minute. No fixing, just noticing.',
    prompts: [
      'What gave you energy today, and what drained it?',
      'What is one thing you handled well recently?',
      'Who made your day slightly better lately, and how?',
      'What would "good enough" look like for tomorrow?',
      'What is something you can let go of tonight?',
    ],
  ),
  Activity(
    id: 'daily_prompt',
    title: "Today's prompt",
    description: 'One prompt per day, picked by the calendar.',
    prompts: [
      'What is one kind thing you could do today?',
      'What skill would you like to be a little better at?',
      'Describe a place where you feel completely at ease.',
      'What is a small win you are proud of?',
      'If you could ask your future self one question, what would it be?',
      'What sound, smell, or taste instantly improves your mood?',
      'What is something new you tried lately — or want to try?',
    ],
  ),
];

/// Instant local fun with no state: coin flip / dice roll.
/// Kept separate from prompts because it produces a result, not a question.
class InstantFun {
  static String coinFlip(Random r) =>
      r.nextBool() ? 'The coin says: HEADS.' : 'The coin says: TAILS.';
  static String diceRoll(Random r, [int sides = 6]) =>
      'You rolled a ${r.nextInt(sides) + 1} (d$sides).';
}

Activity? activityById(String id) {
  for (final a in builtInActivities) {
    if (a.id == id) return a;
  }
  return null;
}

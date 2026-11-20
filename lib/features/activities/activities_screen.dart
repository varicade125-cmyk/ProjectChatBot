import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../navigation/app_router.dart';
import '../../theme/app_tokens.dart';
import 'activities.dart';

/// Offline activity hub. Every activity is prewritten content from
/// [builtInActivities]; prompts can be copied or opened in Chat.
/// Instant fun (coin/dice) resolves locally with [Random].
class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  final Random _random = Random();
  String? _expandedId;
  String? _shownPrompt;
  String? _funResult;

  void _open(Activity a) {
    setState(() {
      _expandedId = _expandedId == a.id ? null : a.id;
      _shownPrompt = null;
      if (_expandedId == a.id) {
        _shownPrompt = a.promptFor(DateTime.now(), random: _random);
      }
    });
  }

  void _another(Activity a) {
    setState(
        () => _shownPrompt = a.promptFor(DateTime.now(), random: _random));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activities')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppTokens.spaceMd),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.spaceMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Instant fun',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppTokens.spaceSm),
                    Wrap(
                      spacing: AppTokens.spaceSm,
                      children: [
                        FilledButton.tonal(
                          onPressed: () => setState(() =>
                              _funResult =
                                  InstantFun.coinFlip(_random)),
                          child: const Text('Flip a coin'),
                        ),
                        FilledButton.tonal(
                          onPressed: () => setState(() =>
                              _funResult =
                                  InstantFun.diceRoll(_random)),
                          child: const Text('Roll a die'),
                        ),
                      ],
                    ),
                    if (_funResult != null) ...[
                      const SizedBox(height: AppTokens.spaceSm),
                      Text(_funResult!,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTokens.spaceSm),
            for (final a in builtInActivities)
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: Text(a.title),
                      subtitle: Text(a.description),
                      trailing: Icon(
                        _expandedId == a.id
                            ? Icons.expand_less
                            : Icons.expand_more,
                      ),
                      onTap: () => _open(a),
                    ),
                    if (_expandedId == a.id && _shownPrompt != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppTokens.spaceMd,
                          0,
                          AppTokens.spaceMd,
                          AppTokens.spaceMd,
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _shownPrompt!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge,
                            ),
                            const SizedBox(
                                height: AppTokens.spaceSm),
                            Wrap(
                              spacing: AppTokens.spaceSm,
                              children: [
                                OutlinedButton(
                                  onPressed: () => _another(a),
                                  child: const Text('Another'),
                                ),
                                OutlinedButton(
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(
                                          text: _shownPrompt!),
                                    );
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('Prompt copied.'),
                                      ),
                                    );
                                  },
                                  child: const Text('Copy'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.of(context).pushNamed(
                                    AppRoutes.chat,
                                    arguments: {
                                      'initialPrompt': _shownPrompt!,
                                    },
                                  ),
                                  child:
                                      const Text('Open in chat'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

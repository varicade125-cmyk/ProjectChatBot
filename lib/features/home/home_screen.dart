import 'package:flutter/material.dart';

import '../../core/scope/app_scope.dart';
import '../../navigation/app_router.dart';
import '../../theme/app_tokens.dart';
import '../companion/avatars.dart';
import '../daily/daily_content.dart';

/// S2 Home / Companion — local-only hub.
/// Companion header (name + look from profile), optional daily card,
/// resume + starters, navigation to conversations/activities/settings.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _starters = [
    'Just say hi',
    'Plan my day',
    'Help me focus',
  ];

  String _name = 'Companion';
  String? _avatarRef;
  String? _userName;
  bool _showGreeting = true;
  bool _showQuestion = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final scope = AppScope.of(context);
      final profile = await scope.companion.getOrCreate();
      final greeting = await scope.settings.dailyGreeting();
      final question = await scope.settings.dailyQuestion();
      if (!mounted) return;
      setState(() {
        _name = profile.name;
        _avatarRef = profile.avatarRef;
        _userName = profile.userName;
        _showGreeting = greeting;
        _showQuestion = question;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Companion'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context)
                .pushNamed(AppRoutes.settings)
                .then((_) => _load()),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppTokens.spaceMd),
                children: [
                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(AppTokens.spaceMd),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: AppTokens.avatarLg / 2,
                            backgroundColor: scheme.primaryContainer,
                            child: Icon(
                              avatarIconFor(_avatarRef),
                              size: 36,
                              color: scheme.onPrimaryContainer,
                              semanticLabel: 'Companion avatar',
                            ),
                          ),
                          const SizedBox(width: AppTokens.spaceMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _name,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(
                                    height: AppTokens.spaceXs),
                                const Text(
                                  'Your private on-device companion space.',
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Customize companion',
                            onPressed: () =>
                                Navigator.of(context)
                                    .pushNamed(AppRoutes.customize)
                                    .then((_) => _load()),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showGreeting || _showQuestion) ...[
                    const SizedBox(height: AppTokens.spaceMd),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(
                            AppTokens.spaceMd),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            if (_showGreeting)
                              Text(
                                DailyContent.greeting(now, _userName),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium,
                              ),
                            if (_showGreeting && _showQuestion)
                              const SizedBox(
                                  height: AppTokens.spaceXs),
                            if (_showQuestion)
                              Text(DailyContent.questionFor(now)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppTokens.spaceMd),
                  SizedBox(
                    height: AppTokens.touchTarget,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context)
                          .pushNamed(AppRoutes.chat),
                      icon:
                          const Icon(Icons.chat_bubble_outline),
                      label: const Text('Resume conversation'),
                    ),
                  ),
                  const SizedBox(height: AppTokens.spaceSm),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: AppTokens.touchTarget,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                Navigator.of(context)
                                    .pushNamed(AppRoutes.history)
                                    .then((_) => _load()),
                            icon: const Icon(Icons.history),
                            label:
                                const Text('Conversations'),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTokens.spaceSm),
                      Expanded(
                        child: SizedBox(
                          height: AppTokens.touchTarget,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                Navigator.of(context).pushNamed(
                                    AppRoutes.activities),
                            icon: const Icon(
                                Icons.extension_outlined),
                            label: const Text('Activities'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.spaceMd),
                  Text(
                    'Try a starter',
                    style:
                        Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppTokens.spaceSm),
                  for (final s in _starters)
                    Padding(
                      padding: const EdgeInsets.only(
                          bottom: AppTokens.spaceSm),
                      child: SizedBox(
                        height: AppTokens.touchTarget,
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(context).pushNamed(
                            AppRoutes.chat,
                            arguments: {'initialPrompt': s},
                          ),
                          child: Text(s),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

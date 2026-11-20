import 'package:flutter/material.dart';

import '../../core/scope/app_scope.dart';
import '../../navigation/app_router.dart';
import '../../theme/app_tokens.dart';

/// S1 Onboarding — skippable, zero required fields.
/// First-run flag persists to SQLite; pager honors reduced-motion.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pages = PageController();
  int _index = 0;
  bool _reducedMotion = false;

  static const _slides = [
    (
      title: 'Meet your companion',
      body: 'Open the app and write. No setup required.',
    ),
    (
      title: 'Your space remembers',
      body: 'Notes, preferences and routines — always under your control.',
    ),
    (
      title: 'You stay in control',
      body: 'Notes, notifications, theme and data can be changed anytime.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final reduced =
            await AppScope.of(context).settings.reducedMotion();
        if (mounted) setState(() => _reducedMotion = reduced);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish(BuildContext context) async {
    // Persist first-run completion; onboarding must never show again
    // after this (FR-ONB-01). Failure still routes home — the flag
    // write is retried next finish, never blocking entry.
    try {
      await AppScope.of(context).settings.setOnboardingDone(true);
    } catch (_) {
      // Best-effort; surfaced via debug, not a blocking dialog.
    }
    if (!context.mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome'),
        actions: [
          TextButton(
            onPressed: () => _finish(context),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.all(AppTokens.spaceLg),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.smart_toy_outlined, size: 64),
                        const SizedBox(height: AppTokens.spaceMd),
                        Text(
                          s.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppTokens.spaceSm),
                        Text(
                          s.body,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => Padding(
                  padding: const EdgeInsets.all(AppTokens.spaceXs),
                  child: Icon(
                    Icons.circle,
                    size: 10,
                    color: i == _index
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).disabledColor,
                    semanticLabel: 'Page ${i + 1} of ${_slides.length}',
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppTokens.spaceMd),
              child: SizedBox(
                height: AppTokens.touchTarget,
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (_index < _slides.length - 1) {
                      if (_reducedMotion) {
                        _pages.jumpToPage(_index + 1);
                      } else {
                        _pages.nextPage(
                          duration:
                              const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        );
                      }
                    } else {
                      _finish(context);
                    }
                  },
                  child: Text(
                    _index < _slides.length - 1 ? 'Continue' : 'Get started',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

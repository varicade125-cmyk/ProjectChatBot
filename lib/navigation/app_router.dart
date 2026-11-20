import 'package:flutter/material.dart';

import '../features/activities/activities_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/companion/companion_customization_screen.dart';
import '../features/conversations/conversation_history_screen.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/settings/about_screen.dart';
import '../features/settings/settings_screen.dart';

/// Named routes (Navigator 1.0, no new dependencies).
/// Chat accepts either a bare String (legacy initial prompt, used by Home
/// starters) or a Map {conversationId?, initialPrompt?}.
/// Unknown routes fall back to home.
abstract final class AppRoutes {
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String chat = '/chat';
  static const String history = '/history';
  static const String activities = '/activities';
  static const String customize = '/customize';
  static const String settings = '/settings';
  static const String about = '/about';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.onboarding:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const OnboardingScreen(),
        );
      case AppRoutes.home:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const HomeScreen(),
        );
      case AppRoutes.chat:
        final args = settings.arguments;
        final map = args is Map ? args : const {};
        final initialPrompt =
            args is String ? args : map['initialPrompt'] as String?;
        final conversationId = map['conversationId'] as String?;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ChatScreen(
            initialPrompt: initialPrompt,
            conversationId: conversationId,
          ),
        );
      case AppRoutes.history:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ConversationHistoryScreen(),
        );
      case AppRoutes.activities:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ActivitiesScreen(),
        );
      case AppRoutes.customize:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const CompanionCustomizationScreen(),
        );
      case AppRoutes.settings:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const SettingsScreen(),
        );
      case AppRoutes.about:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const AboutScreen(),
        );
      default:
        return MaterialPageRoute(
          settings: const RouteSettings(name: AppRoutes.home),
          builder: (_) => const HomeScreen(),
        );
    }
  }
}

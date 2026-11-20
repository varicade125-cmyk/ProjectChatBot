import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_companion/core/scope/app_scope.dart';
import 'package:ai_companion/data/models/message.dart';
import 'package:ai_companion/features/ai/ai_provider.dart';
import 'package:ai_companion/features/chat/chat_screen.dart';
import 'package:ai_companion/features/home/home_screen.dart';
import 'package:ai_companion/features/onboarding/onboarding_screen.dart';
import 'package:ai_companion/main.dart';
import 'package:ai_companion/navigation/app_router.dart';

import 'fakes.dart';

/// Widget tests run on in-memory fakes (no ffi sqlite: it deadlocks under
/// TestWidgetsFlutterBinding in this environment — see test/fakes.dart).
/// SQL behavior is covered separately by db_test.dart.
///
/// Scrolls the first ListView until [target] is built, then brings it
/// fully on-screen. Long settings/history lists render lazily.
Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  for (var i = 0;
      i < 15 && target.evaluate().isEmpty;
      i++) {
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

/// Pumps the app at [initialRoute] with a fresh fake scope.
/// NOTE: MaterialApp reads initialRoute only at first build — re-pumping a
/// different route keeps the old tree. Reach other screens via navigation.
Future<AppScopeData> _pump(
  WidgetTester tester, {
  String initialRoute = AppRoutes.home,
}) async {
  final scope = makeFakeScope();
  await tester.pumpWidget(
    CompanionApp(scopeOverride: scope, initialRouteOverride: initialRoute),
  );
  await tester.pumpAndSettle();
  return scope;
}

void main() {
  testWidgets('app boots to onboarding with Skip visible',
      (WidgetTester tester) async {
    final scope =
        await _pump(tester, initialRoute: AppRoutes.onboarding);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    await scope.close();
  });

  testWidgets('Skip persists onboarding-done and goes Home',
      (WidgetTester tester) async {
    final scope =
        await _pump(tester, initialRoute: AppRoutes.onboarding);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(await scope.settings.isOnboardingDone(), isTrue);
    await scope.close();
  });

  testWidgets('sent message persists and survives screen rebuild',
      (WidgetTester tester) async {
    final scope = await _pump(tester, initialRoute: AppRoutes.home);
    await tester.tap(find.text('Resume conversation'));
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'hello persisted');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(find.text('hello persisted'), findsOneWidget);

    // Rebuild from scratch: message must come back from storage.
    await tester.pumpWidget(
      CompanionApp(
          scopeOverride: scope, initialRouteOverride: AppRoutes.chat),
    );
    await tester.pumpAndSettle();
    expect(find.text('hello persisted'), findsOneWidget);
    await scope.close();
  });

  testWidgets('draft survives screen rebuild',
      (WidgetTester tester) async {
    final scope = await _pump(tester, initialRoute: AppRoutes.chat);
    await tester.enterText(find.byType(TextField), 'half-typed…');
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpWidget(
      CompanionApp(
          scopeOverride: scope, initialRouteOverride: AppRoutes.chat),
    );
    await tester.pumpAndSettle();
    expect(find.text('half-typed…'), findsOneWidget);
    await scope.close();
  });

  testWidgets('unknown route falls back to Home',
      (WidgetTester tester) async {
    final scope = makeFakeScope();
    await tester.pumpWidget(
      AppScope(
        data: scope,
        child: const MaterialApp(
          onGenerateRoute: AppRoutes.onGenerateRoute,
          initialRoute: '/nope',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    await scope.close();
  });

  testWidgets('auto-reply answers with labeled programmed reply',
      (WidgetTester tester) async {
    final scope = await _pump(tester, initialRoute: AppRoutes.chat);
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(find.text('hello'), findsOneWidget);
    expect(find.text('programmed reply • not AI'), findsOneWidget);
    await scope.close();
  });

  testWidgets('auto-reply off: no programmed reply',
      (WidgetTester tester) async {
    final scope = makeFakeScope();
    await scope.settings.setAutoReply(false);
    await tester.pumpWidget(
      CompanionApp(scopeOverride: scope, initialRouteOverride: AppRoutes.chat),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(find.text('hello'), findsOneWidget);
    expect(find.text('programmed reply • not AI'), findsNothing);
    await scope.close();
  });

  testWidgets('history: create, rename, delete conversation',
      (WidgetTester tester) async {
    final scope =
        await _pump(tester, initialRoute: AppRoutes.history);
    expect(
        find.textContaining('No conversations yet'), findsOneWidget);

    // Create.
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('New conversation'), findsOneWidget);

    // Rename (scoped to the dialog: the search field is also a TextField).
    await tester.tap(find.byTooltip('Conversation options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    final dialogField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogField, 'Renamed');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Renamed'), findsOneWidget);

    // Delete with confirm.
    await tester.tap(find.byTooltip('Conversation options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('No conversations yet'), findsOneWidget);
    await scope.close();
  });

  testWidgets('customize: save name persists to profile',
      (WidgetTester tester) async {
    final scope =
        await _pump(tester, initialRoute: AppRoutes.customize);
    await tester.enterText(find.byType(TextField).first, 'Buddy');
    const saveButton = ValueKey('customizeSaveButton');
    for (var i = 0;
        i < 15 && find.byKey(saveButton).evaluate().isEmpty;
        i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.byKey(saveButton).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(saveButton).first);
    await tester.pumpAndSettle();
    expect(await scope.companion.getOrCreate().then((p) => p.name),
        'Buddy');
    await scope.close();
  });

  testWidgets('settings: programmed-replies toggle persists',
      (WidgetTester tester) async {
    final scope =
        await _pump(tester, initialRoute: AppRoutes.settings);
    expect(await scope.settings.autoReply(), isTrue);
    await tester.tap(find.text('Programmed replies'));
    await tester.pumpAndSettle();
    // SwitchListTile tap toggles; allow async write to land.
    await tester.pump(const Duration(milliseconds: 100));
    expect(await scope.settings.autoReply(), isFalse);
    await scope.close();
  });

  testWidgets('activities: open prompt in chat',
      (WidgetTester tester) async {
    final scope =
        await _pump(tester, initialRoute: AppRoutes.activities);
    expect(find.text('Trivia (self-checked)'), findsOneWidget);
    await tester.tap(find.text('Trivia (self-checked)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Open in chat'));
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsOneWidget);
    await scope.close();
  });

  testWidgets('all routes resolve', (WidgetTester tester) async {
    final scope = makeFakeScope();
    for (final route in [
      AppRoutes.history,
      AppRoutes.activities,
      AppRoutes.customize,
      AppRoutes.settings,
      AppRoutes.about,
    ]) {
      await tester.pumpWidget(
        CompanionApp(scopeOverride: scope, initialRouteOverride: route),
      );
      await tester.pumpAndSettle();
    }
    // Last route rendered without errors; scope still usable.
    expect(await scope.settings.autoReply(), isTrue);
    await scope.close();
  });

  testWidgets('about shows version', (WidgetTester tester) async {
    await _pump(tester, initialRoute: AppRoutes.about);
    expect(find.textContaining('Version 1.0.0+1'), findsOneWidget);
    expect(find.textContaining('never'), findsWidgets);
  });

  testWidgets('AI enabled: remote reply labeled AI, metadata kept',
      (WidgetTester tester) async {
    final remote = FakeRemoteProvider()
      ..handler = (_) async => 'ai says hi';
    final scope = makeFakeScope(remote: remote);
    await scope.settings.setAiEnabled(true);
    await scope.settings.setAiModeName('auto');
    await tester.pumpWidget(
      CompanionApp(scopeOverride: scope, initialRouteOverride: AppRoutes.chat),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'hello ai');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(find.text('hello ai'), findsOneWidget);
    expect(find.text('ai says hi'), findsOneWidget);
    expect(find.text('AI reply • remote service'), findsOneWidget);
    expect(find.text('programmed reply • not AI'), findsNothing);
    await scope.close();
  });

  testWidgets('AI remoteOnly failure shows error card, retry recovers',
      (WidgetTester tester) async {
    var attempts = 0;
    final remote = FakeRemoteProvider()
      ..handler = (_) async {
        attempts++;
        if (attempts == 1) throw AiFailure.rateLimit();
        return 'recovered';
      };
    final scope = makeFakeScope(remote: remote);
    await scope.settings.setAiEnabled(true);
    await scope.settings.setAiModeName('remoteOnly');
    await tester.pumpWidget(
      CompanionApp(scopeOverride: scope, initialRouteOverride: AppRoutes.chat),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'please fail once');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    // User row kept, no fake assistant row, error card shown.
    expect(find.text('please fail once'), findsOneWidget);
    expect(find.textContaining('rate-limiting'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();
    expect(find.text('recovered'), findsOneWidget);
    expect(find.text('AI reply • remote service'), findsOneWidget);
    // Still exactly one user row: retry never duplicates.
    final conv = await scope.conversations.ensureDefault();
    final thread = await scope.messages.page(conv.id, limit: 10);
    expect(
        thread.where((m) => m.role == MessageRole.user).length, 1);
    await scope.close();
  });

  testWidgets('settings AI section toggles + persists',
      (WidgetTester tester) async {
    final scope = makeFakeScope();
    await tester.pumpWidget(
      CompanionApp(
          scopeOverride: scope,
          initialRouteOverride: AppRoutes.settings),
    );
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Enable remote AI'));
    expect(find.text('Enable remote AI'), findsOneWidget);
    await tester.tap(find.text('Enable remote AI'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(await scope.settings.aiEnabled(), isTrue);
    await scope.close();
  });

  testWidgets('history search filters and shows no-match state',
      (WidgetTester tester) async {
    final scope = makeFakeScope();
    await scope.conversations.create(title: 'Alpha notes');
    await scope.conversations.create(title: 'Beta diary');
    await tester.pumpWidget(
      CompanionApp(
          scopeOverride: scope, initialRouteOverride: AppRoutes.history),
    );
    await tester.pumpAndSettle();
    expect(find.text('Alpha notes'), findsOneWidget);
    expect(find.text('Beta diary'), findsOneWidget);

    await tester.enterText(
        find.byType(TextField), 'alp');
    await tester.pumpAndSettle();
    expect(find.text('Alpha notes'), findsOneWidget);
    expect(find.text('Beta diary'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.textContaining('No matches'), findsOneWidget);
    await scope.close();
  });

  testWidgets('history pin + archive + unarchive flows',
      (WidgetTester tester) async {
    final scope = makeFakeScope();
    final conv = await scope.conversations.create(title: 'Pinned soon');
    await tester.pumpWidget(
      CompanionApp(
          scopeOverride: scope, initialRouteOverride: AppRoutes.history),
    );
    await tester.pumpAndSettle();

    // Pin.
    await tester.tap(find.byTooltip('Conversation options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pin'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
    expect((await scope.conversations.byId(conv.id))!.isPinned, isTrue);

    // Archive moves it out of Active.
    await tester.tap(find.byTooltip('Conversation options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    expect(find.text('Pinned soon'), findsNothing);

    // Archived segment shows it; unarchive restores it.
    await tester.tap(find.text('Archived'));
    await tester.pumpAndSettle();
    expect(find.text('Pinned soon'), findsOneWidget);
    await tester.tap(find.byTooltip('Conversation options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unarchive'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();
    expect(find.text('Pinned soon'), findsOneWidget);
    await scope.close();
  });

  testWidgets('message long-press copies text',
      (WidgetTester tester) async {
    final copied = <String>[];
    final scope = makeFakeScope();
    await tester.pumpWidget(
      CompanionApp(scopeOverride: scope, initialRouteOverride: AppRoutes.chat),
    );
    await tester.pumpAndSettle();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.enterText(find.byType(TextField), 'copy me please');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('copy me please'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(copied, contains('copy me please'));
    await scope.close();
  });

  testWidgets('message delete removes bubble after confirm',
      (WidgetTester tester) async {
    final scope = await _pump(tester, initialRoute: AppRoutes.chat);
    await tester.enterText(find.byType(TextField), 'delete me please');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(find.text('delete me please'), findsOneWidget);

    await tester.longPress(find.text('delete me please'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('delete me please'), findsNothing);
    await scope.close();
  });

  testWidgets('settings export → reset → import round-trips',
      (WidgetTester tester) async {
    String? clipboard;
    final scope = makeFakeScope();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard =
              (call.arguments as Map)['text'] as String?;
          return null;
        }
        if (call.method == 'Clipboard.getData') {
          return {'text': clipboard};
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    // Seed directly (send path is covered by the message tests).
    final conv = await scope.conversations.ensureDefault();
    await scope.messages.insert(
      conversationId: conv.id,
      role: MessageRole.user,
      body: 'round trip',
    );

    // Export from settings, wipe, import back. Single pump: MaterialApp
    // reads initialRoute only at first build, so re-pumping a different
    // route would silently keep the old tree.
    await tester.pumpWidget(
      CompanionApp(
          scopeOverride: scope, initialRouteOverride: AppRoutes.settings),
    );
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Export data'));
    await tester.tap(find.text('Export data'));
    await tester.pumpAndSettle();
    expect(clipboard, isNotNull);
    // Let the export snackbar expire so the later import snackbar is not
    // queued behind it.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await scope.resetAll();
    expect(await scope.conversations.listRecent(), isEmpty);

    await _scrollTo(tester, find.text('Import data'));
    await tester.tap(find.text('Import data'));
    await tester.pumpAndSettle();
    // Confirm dialog states validated counts before anything is written.
    expect(find.textContaining('Found 1 conversation(s)'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    // Catch the transient success snackbar before settle dismisses it.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Imported 1 conversation'), findsOneWidget);
    await tester.pumpAndSettle();
    final titles = (await scope.conversations.listRecent(limit: 10))
        .map((c) => c.title)
        .toList();
    expect(titles, contains('General'));
    await scope.close();
  });
}

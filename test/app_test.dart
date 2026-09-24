import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillcheck/app/app.dart';
import 'package:skillcheck/app/router/app_router.dart';

void main() {
  testWidgets('home action and bottom destinations navigate', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SkillCheckApp()));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to SkillCheck'), findsOneWidget);
    await tester.tap(find.text('Explore assessments'));
    await tester.pumpAndSettle();
    expect(find.text('Assessments are coming soon'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    for (final entry in {
      'Progress': 'Progress tracking is coming soon',
      'Profile': 'Your account is coming soon',
      'Home': 'Welcome to SkillCheck',
    }.entries) {
      await tester.tap(find.widgetWithText(NavigationDestination, entry.key));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
    }
  });

  testWidgets('theme selection updates app and survives navigation', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: SkillCheckApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, 'Profile'));
    await tester.pumpAndSettle();
    for (final entry in {
      'Dark': ThemeMode.dark,
      'Light': ThemeMode.light,
      'System': ThemeMode.system,
    }.entries) {
      await tester.tap(find.byType(DropdownButtonFormField<ThemeMode>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry.key).last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        entry.value,
      );
      await tester.tap(find.widgetWithText(NavigationDestination, 'Home'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to SkillCheck'), findsOneWidget);
      await tester.tap(find.widgetWithText(NavigationDestination, 'Profile'));
      await tester.pumpAndSettle();
      expect(find.text(entry.key), findsOneWidget);
    }
  });

  testWidgets('unknown route offers recovery', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SkillCheckApp(),
      ),
    );
    container.read(appRouterProvider).go('/missing');
    await tester.pumpAndSettle();
    expect(find.text('Page not found'), findsOneWidget);
    await tester.tap(find.text('Back to Home'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to SkillCheck'), findsOneWidget);
  });

  testWidgets('small phone with enlarged text does not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const ProviderScope(child: SkillCheckApp()));
    await tester.pumpAndSettle();
    for (final label in ['Assessments', 'Progress', 'Profile', 'Home']) {
      await tester.tap(find.widgetWithText(NavigationDestination, label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}

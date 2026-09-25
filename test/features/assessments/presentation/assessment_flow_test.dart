import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillcheck/app/app.dart';
import 'package:skillcheck/app/router/app_router.dart';
import 'package:skillcheck/features/assessments/application/assessment_controller.dart';

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Home to mixed result and answer review, preserving choices across tabs',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: SkillCheckApp()));
      await tester.pumpAndSettle();
      await tapText(tester, 'Explore assessments');
      await tapText(tester, 'Start English');
      expect(find.text('Question 1 of 3'), findsOneWidget);
      expect(find.textContaining('Explanation:'), findsNothing);
      await tapText(tester, 'goes');
      await tapText(tester, 'Next');
      await tapText(tester, 'False');
      await tapText(tester, 'Previous');
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      await tester.tap(find.widgetWithText(NavigationDestination, 'Home'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(NavigationDestination, 'Assessments'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Question 1 of 3'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      await tapText(tester, 'Next');
      await tapText(tester, 'Next');
      expect(find.text('Question 3 of 3'), findsOneWidget);
      await tapText(tester, 'Submit assessment');
      expect(find.text('25.0%'), findsOneWidget);
      expect(find.text('Score: 1 / 4 points'), findsOneWidget);
      expect(find.text('Correct: 1'), findsOneWidget);
      expect(find.text('Incorrect: 1'), findsOneWidget);
      expect(find.text('Skipped: 1'), findsOneWidget);
      await tapText(tester, 'Review answers');
      expect(find.text('Your answer: goes'), findsOneWidget);
      expect(find.text('Correct answer: goes'), findsOneWidget);
      expect(find.text('Your answer: False'), findsOneWidget);
      expect(find.text('Correct answer: True'), findsOneWidget);
      expect(find.text('Your answer: Skipped'), findsOneWidget);
      expect(find.textContaining('Explanation:'), findsNWidgets(3));
      await tapText(tester, 'Back to result');
      expect(find.text('25.0%'), findsOneWidget);
      await tapText(tester, 'Back to assessments');
      await tapText(tester, 'Start English');
      expect(find.text('0 answered • 3 unanswered'), findsOneWidget);
    },
  );

  testWidgets('clear answer and submit all skipped', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SkillCheckApp(),
      ),
    );
    container.read(assessmentControllerProvider.notifier).start('english');
    container.read(appRouterProvider).go('/assessments/session');
    await tester.pumpAndSettle();
    await tapText(tester, 'goes');
    await tapText(tester, 'Clear answer');
    expect(find.byIcon(Icons.radio_button_checked), findsNothing);
    await tapText(tester, 'Next');
    await tapText(tester, 'Next');
    await tapText(tester, 'Submit assessment');
    expect(find.text('0.0%'), findsOneWidget);
    expect(find.text('Skipped: 3'), findsOneWidget);
  });

  testWidgets('replacing an unfinished attempt requires explicit choice', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SkillCheckApp(),
      ),
    );
    final controller = container.read(assessmentControllerProvider.notifier);
    controller.start('english');
    controller.selectAnswer('en_1_1');
    container.read(appRouterProvider).go('/assessments');
    await tester.pumpAndSettle();
    await tapText(tester, 'Start Kazakh');
    await tapText(tester, 'Cancel');
    expect(
      container.read(assessmentControllerProvider)!.selections['en_1'],
      'en_1_1',
    );
    await tapText(tester, 'Resume English');
    expect(find.text('Question 1 of 3'), findsOneWidget);
    container.read(appRouterProvider).go('/assessments');
    await tester.pumpAndSettle();
    await tapText(tester, 'Start Kazakh');
    await tapText(tester, 'Start new attempt');
    expect(container.read(assessmentControllerProvider)!.category.id, 'kazakh');
    expect(find.text('0 answered • 3 unanswered'), findsOneWidget);
  });

  testWidgets(
    'direct routes without an attempt recover safely and review is gated',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SkillCheckApp(),
        ),
      );
      for (final route in ['session', 'result', 'review']) {
        container.read(appRouterProvider).go('/assessments/$route');
        await tester.pumpAndSettle();
        expect(find.text('No result available'), findsOneWidget);
      }
      container.read(assessmentControllerProvider.notifier).start('english');
      container.read(appRouterProvider).go('/assessments/review');
      await tester.pumpAndSettle();
      expect(find.textContaining('Correct answer:'), findsNothing);
      await tapText(tester, 'Back to assessments');
      expect(find.text('Resume English'), findsOneWidget);
    },
  );

  testWidgets(
    'phone layout with enlarged text supports question, result and review',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SkillCheckApp(),
        ),
      );
      container
          .read(assessmentControllerProvider.notifier)
          .start('programming');
      container.read(appRouterProvider).go('/assessments/session');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tapText(tester, 'Next');
      await tapText(tester, 'Next');
      await tapText(tester, 'Submit assessment');
      expect(tester.takeException(), isNull);
      await tapText(tester, 'Review answers');
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.textContaining('Explanation: The ~/'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

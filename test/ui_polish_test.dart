import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillcheck/app/app.dart';
import 'package:skillcheck/app/router/app_router.dart';
import 'package:skillcheck/app/theme/app_theme.dart';
import 'package:skillcheck/app/theme/theme_mode_provider.dart';
import 'package:skillcheck/features/auth/presentation/auth_screen.dart';
import 'package:skillcheck/features/assessments/application/assessment_controller.dart';
import 'package:skillcheck/features/assessments/domain/models/category.dart';
import 'package:skillcheck/features/assessments/domain/models/question.dart';
import 'package:skillcheck/features/assessments/domain/models/question_option.dart';

import 'fixtures/fake_repositories.dart';
import 'features/progress/progress_test.dart' show historyAttempt;

import 'package:skillcheck/features/progress/domain/assessment_history.dart';
import 'package:skillcheck/features/progress/application/progress_providers.dart';

void smallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  testWidgets('selected category remains safe when catalogue is unavailable', (
    tester,
  ) async {
    final repo = ControlledAssessmentRepository()..failCategories = true;
    final c = testContainer(repository: repo);
    addTearDown(c.dispose);
    c.read(progressCategoryProvider.notifier).select('english');
    await tester.pumpWidget(
      UncontrolledProviderScope(container: c, child: const SkillCheckApp()),
    );
    c.read(appRouterProvider).go('/progress');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Unavailable category'), findsOneWidget);
    expect(find.text('No completed assessments yet'), findsOneWidget);
    expect(c.read(progressCategoryProvider), 'english');
    // Let Riverpod's automatic retry recover, rather than leave a pending timer.
    repo.failCategories = false;
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Unavailable category'), findsNothing);
    expect(c.read(progressCategoryProvider), 'english');
  });
  for (final width in [320.0, 1280.0]) {
    testWidgets(
      'Progress and Profile at width $width with 200% text in both themes',
      (tester) async {
        smallScreen(tester);
        tester.view.physicalSize = Size(width, 720);
        final repo = ControlledAssessmentRepository();
        final longName = List.filled(10, 'Long category name').join(' ');
        repo.categories = [
          Category(id: 'english', name: longName, description: longName),
        ];
        final history = FakeProgressRepository()
          ..saved['user-a'] = {
            for (var i = 0; i < 10; i++)
              '$i': HistoryAttempt(
                userId: 'user-a',
                categoryName: longName,
                result: historyAttempt('$i', day: i + 1).result,
              ),
          };
        final c = testContainer(repository: repo, progress: history);
        addTearDown(c.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(container: c, child: const SkillCheckApp()),
        );
        for (final theme in [ThemeMode.light, ThemeMode.dark]) {
          c.read(themeModeProvider.notifier).setThemeMode(theme);
          c.read(appRouterProvider).go('/progress');
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Assessment history'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          c.read(appRouterProvider).go('/profile');
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.byType(DropdownButtonFormField<ThemeMode>),
          );
          await tester.tap(find.byType(DropdownButtonFormField<ThemeMode>));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('System').last);
          await tester.pumpAndSettle();
        }
      },
    );
  }
  for (final dark in [false, true]) {
    for (final mode in AuthFormMode.values) {
      testWidgets('$mode form at 320px, 200% text, dark=$dark', (tester) async {
        smallScreen(tester);
        final c = testContainer(auth: FakeAuthRepository(signedIn: false));
        addTearDown(c.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: c,
            child: MaterialApp(
              theme: dark ? AppTheme.dark : AppTheme.light,
              home: AuthScreen(mode: mode),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final submit = find.byType(FilledButton);
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (mode != AuthFormMode.forgotPassword) {
          final show = find.byTooltip('Show password');
          await tester.ensureVisible(show);
          await tester.tap(show);
          await tester.pump();
          expect(find.byTooltip('Hide password'), findsOneWidget);
          expect(
            tester
                .widget<TextFormField>(
                  find.widgetWithText(TextFormField, 'Password'),
                )
                .controller,
            isNotNull,
          );
          final field = tester.widget<TextField>(
            find.descendant(
              of: find.widgetWithText(TextFormField, 'Password'),
              matching: find.byType(TextField),
            ),
          );
          expect(field.obscureText, isFalse);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('keyboard Done signs in and password action has a 48px target', (
    tester,
  ) async {
    final c = testContainer(auth: FakeAuthRepository(signedIn: false));
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: c, child: const SkillCheckApp()),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'test@example.test',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password123',
    );
    expect(
      tester.getSize(find.byTooltip('Show password')).height,
      greaterThanOrEqualTo(48),
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Welcome to SkillCheck'), findsOneWidget);
  });
  testWidgets('long content and Back preserve answers in both themes', (
    tester,
  ) async {
    smallScreen(tester);
    final repo = ControlledAssessmentRepository();
    final original = repo.questions.first;
    final longName = List.filled(8, 'Long category name').join(' ');
    repo.categories = [
      Category(id: 'english', name: longName, description: longName),
    ];
    repo.questions = [
      Question(
        id: original.id,
        categoryId: original.categoryId,
        topicId: original.topicId,
        questionText: List.filled(8, original.questionText).join(' '),
        type: original.type,
        difficulty: original.difficulty,
        options: [
          for (final option in original.options)
            QuestionOption(
              id: option.id,
              text: List.filled(10, option.text).join(' '),
            ),
        ],
        correctOptionId: original.correctOptionId,
        explanation: List.filled(20, original.explanation).join(' '),
      ),
    ];
    final c = testContainer(repository: repo);
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: c, child: const SkillCheckApp()),
    );
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      c.read(themeModeProvider.notifier).setThemeMode(mode);
      final controller = c.read(assessmentControllerProvider.notifier);
      await controller.start('english');
      c.read(appRouterProvider).go('/assessments/session');
      await tester.pumpAndSettle();
      final option = find.byKey(ValueKey(original.correctOptionId));
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pump();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(
        c.read(assessmentControllerProvider)!.selections[original.id],
        original.correctOptionId,
      );
      await controller.submit();
      c.read(appRouterProvider).go('/assessments/review');
      await tester.pumpAndSettle();
      expect(find.textContaining('Explanation:'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Correct: 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}

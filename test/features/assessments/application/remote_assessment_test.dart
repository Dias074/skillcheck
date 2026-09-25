import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillcheck/app/app.dart';
import 'package:skillcheck/app/router/app_router.dart';
import 'package:skillcheck/core/errors/app_failure.dart';
import 'package:skillcheck/features/auth/domain/auth_repository.dart';
import 'package:skillcheck/features/assessments/application/assessment_controller.dart';
import 'package:skillcheck/features/assessments/domain/models/question.dart';

import '../../../fixtures/fake_repositories.dart';
import '../../../fixtures/local_question_source.dart';

void main() {
  test('empty/error loads preserve previous session', () async {
    final repository = ControlledAssessmentRepository();
    final container = testContainer(repository: repository);
    addTearDown(container.dispose);
    final controller = container.read(assessmentControllerProvider.notifier);
    await controller.start('english');
    controller.selectAnswer('en_1_1');
    final old = container.read(assessmentControllerProvider);
    repository.questions = [];
    await expectLater(controller.start('english'), throwsA(isA<AppFailure>()));
    expect(
      identical(container.read(assessmentControllerProvider), old),
      isTrue,
    );
    repository.failQuestions = true;
    await expectLater(controller.start('english'), throwsA(isA<AppFailure>()));
    expect(
      identical(container.read(assessmentControllerProvider), old),
      isTrue,
    );
  });

  test(
    'logout prevents an in-flight response from resurrecting private session',
    () async {
      final repository = ControlledAssessmentRepository()
        ..pending = Completer<List<Question>>();
      final auth = FakeAuthRepository();
      final container = testContainer(auth: auth, repository: repository);
      addTearDown(container.dispose);
      addTearDown(auth.dispose);
      final controller = container.read(assessmentControllerProvider.notifier);
      final pending = controller.start('english');
      await Future<void>.delayed(Duration.zero);
      auth.emit(const AuthSnapshot());
      await container.pump();
      repository.pending!.complete(
        const LocalQuestionSource().questions('english'),
      );
      expect(await pending, isFalse);
      expect(container.read(assessmentControllerProvider), isNull);
    },
  );

  testWidgets('category error retries to empty state and then content', (
    tester,
  ) async {
    final repository = ControlledAssessmentRepository()..failCategories = true;
    final container = testContainer(repository: repository);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SkillCheckApp(),
      ),
    );
    container.read(appRouterProvider).go('/assessments');
    await tester.pumpAndSettle();
    expect(find.text('Unable to load categories.'), findsOneWidget);
    repository.failCategories = false;
    repository.categories = [];
    await tester.tap(find.text('Retry categories'));
    await tester.pumpAndSettle();
    expect(
      find.text('No assessment categories are available yet.'),
      findsOneWidget,
    );
    repository.categories = LocalQuestionSource.categories;
    await tester.tap(find.text('Refresh categories'));
    await tester.pumpAndSettle();
    expect(find.text('Start English'), findsOneWidget);
  });

  testWidgets('question loading, empty result and retry succeed', (
    tester,
  ) async {
    final repository = ControlledAssessmentRepository()
      ..pending = Completer<List<Question>>();
    final container = testContainer(repository: repository);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SkillCheckApp(),
      ),
    );
    container.read(appRouterProvider).go('/assessments');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start English'));
    await tester.tap(find.text('Start English'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Loading questions…'), findsOneWidget);
    repository.pending!.complete([]);
    await tester.pumpAndSettle();
    expect(
      find.text('No questions are available for this category yet.'),
      findsOneWidget,
    );
    repository.pending = null;
    await tester.ensureVisible(find.text('Start English'));
    await tester.tap(find.text('Start English'));
    await tester.pumpAndSettle();
    expect(find.text('Question 1 of 3'), findsOneWidget);
  });
}

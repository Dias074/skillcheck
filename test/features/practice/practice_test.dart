import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillcheck/app/app.dart';
import 'package:skillcheck/app/router/app_router.dart';
import 'package:skillcheck/features/assessments/application/assessment_controller.dart';
import 'package:skillcheck/features/assessments/domain/models/question.dart';
import 'package:skillcheck/features/auth/domain/auth_repository.dart';
import 'package:skillcheck/features/practice/domain/practice_question_selector.dart';
import 'package:skillcheck/features/progress/application/progress_providers.dart';
import 'package:skillcheck/features/weak_areas/domain/topic_performance.dart';

import '../../fixtures/fake_repositories.dart';
import '../../fixtures/local_question_source.dart';

List<TopicAnswer> evidence({
  String user = 'user-a',
  String topic = 'english_grammar',
  bool correct = false,
  int count = 6,
}) => [
  for (var i = 0; i < count; i++)
    TopicAnswer(
      userId: user,
      attemptId: 'a${i ~/ 2}',
      questionId: 'q${i % 2}',
      categoryId: 'english',
      categoryName: 'English',
      topicId: topic,
      topicName: topic,
      answered: true,
      isCorrect: correct,
      pointsEarned: correct ? 1 : 0,
      maxPoints: 1,
    ),
];

void main() {
  final bank = const LocalQuestionSource().questions('english');
  test('large question bank is capped at five unique questions', () {
    final template = bank.first;
    final questions = List.generate(
      8,
      (i) => Question(
        id: 'q$i',
        categoryId: template.categoryId,
        topicId: template.topicId,
        questionText: template.questionText,
        type: template.type,
        difficulty: template.difficulty,
        options: template.options,
        correctOptionId: template.correctOptionId,
        explanation: template.explanation,
      ),
    );
    final selected = const PracticeQuestionSelector().select(
      categoryId: 'english',
      topics: const TopicPerformanceCalculator().calculate(
        evidence(),
        userId: 'user-a',
      ),
      questions: questions.reversed.toList(),
      policy: const WeakAreaPolicy(),
    );
    expect(selected.map((q) => q.id), ['q0', 'q1', 'q2', 'q3', 'q4']);
  });
  List<Question> select(
    List<TopicAnswer> answers, {
    List<Question>? questions,
    String category = 'english',
  }) => const PracticeQuestionSelector().select(
    categoryId: category,
    topics: const TopicPerformanceCalculator().calculate(
      answers,
      userId: 'user-a',
    ),
    questions: questions ?? bank,
    policy: const WeakAreaPolicy(),
  );
  test(
    'selects only weak topics, deduplicates and uses existing questions',
    () {
      final selected = select(evidence(), questions: [...bank, ...bank]);
      expect(selected.map((q) => q.id), ['en_1', 'en_3']);
      expect(identical(selected.first, bank.first), isTrue);
    },
  );
  test('no history, insufficient evidence, good topics and another user do not qualify', () {
    for (final rows in [
      <TopicAnswer>[],
      evidence(count: 1),
      evidence(correct: true),
      evidence(user: 'user-b'),
    ]) {
      expect(() => select(rows), throwsA(isA<PracticeUnavailable>()));
    }
    expect(
      () => select(evidence(), category: 'kazakh'),
      throwsA(isA<PracticeUnavailable>()),
    );
  });
  test('requires two different available questions and balances multiple weak topics', () {
    expect(
      () => select(evidence(), questions: [bank.first, bank.first]),
      throwsA(isA<PracticeUnavailable>()),
    );
    final selected = select([
      ...evidence(),
      ...evidence(topic: 'english_vocabulary').map(
        (a) => TopicAnswer(
          userId: a.userId,
          attemptId: 'v${a.attemptId}',
          questionId: a.questionId,
          categoryId: a.categoryId,
          categoryName: a.categoryName,
          topicId: a.topicId,
          topicName: a.topicName,
          answered: a.answered,
          isCorrect: a.isCorrect,
          pointsEarned: a.pointsEarned,
          maxPoints: a.maxPoints,
        ),
      ),
    ]);
    expect(selected.map((q) => q.id), ['en_1', 'en_2', 'en_3']);
  });
  test('practice preserves normal attempt, scores skips and never saves or changes history', () async {
    final progress = FakeProgressRepository();
    final c = testContainer(
      progress: progress,
      topics: FakeTopicRepository()..answers = evidence(),
    );
    addTearDown(c.dispose);
    final normal = c.read(assessmentControllerProvider.notifier);
    await normal.start('english');
    normal.selectAnswer('en_1_1');
    final original = c.read(assessmentControllerProvider);
    final practice = c.read(practiceControllerProvider.notifier);
    expect(practice.mode, SessionMode.practice);
    expect(await practice.start('english'), isTrue);
    practice.selectAnswer('en_1_1');
    practice.next();
    practice.previous();
    expect(c.read(practiceControllerProvider)!.selections['en_1'], 'en_1_1');
    practice.next();
    final result = await practice.submit();
    expect(result.score, 1);
    expect(result.maxScore, 3);
    expect(result.percentage, closeTo(100 / 3, 0.001));
    expect(result.correctAnswers, 1);
    expect(result.incorrectAnswers, 0);
    expect(result.unansweredQuestions, 1);
    expect(await practice.submit(), same(result));
    expect(progress.saveCalls, 0);
    expect(progress.saved, isEmpty);
    expect(c.read(assessmentControllerProvider), same(original));
    expect(c.read(practiceControllerProvider)!.review.length, 2);
    expect(() => practice.selectAnswer('en_3_0'), throwsStateError);
    expect(await practice.start('english'), isTrue);
    practice.selectAnswer('en_1_0');
    practice.next();
    practice.selectAnswer('en_3_0');
    expect((await practice.submit()).incorrectAnswers, 2);
  });
  test(
    'logout clears practice and late loads cannot enter another account',
    () async {
      final auth = FakeAuthRepository();
      final topics = FakeTopicRepository()..answers = evidence();
      final c = testContainer(auth: auth, topics: topics);
      addTearDown(c.dispose);
      addTearDown(auth.dispose);
      final controller = c.read(practiceControllerProvider.notifier);
      await controller.start('english');
      await auth.signOut();
      await Future<void>.delayed(Duration.zero);
      expect(c.read(practiceControllerProvider), isNull);
      await auth.signIn('a@example.test', 'unused');
      await Future<void>.delayed(Duration.zero);
      c.read(practiceControllerProvider);
      final pending = Completer<List<TopicAnswer>>();
      topics.pending['user-a'] = pending;
      final start = controller.start('english');
      await Future<void>.delayed(Duration.zero);
      auth.emit(
        const AuthSnapshot(
          user: AuthUser(id: 'user-b', email: 'b@example.test'),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      c.read(practiceControllerProvider);
      pending.complete(evidence());
      expect(await start, isFalse);
      expect(c.read(practiceControllerProvider), isNull);
    },
  );

  Future<void> pumpApp(
    WidgetTester tester,
    ProviderContainer c,
    String path,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(container: c, child: const SkillCheckApp()),
    );
    c.read(appRouterProvider).go(path);
    await tester.pumpAndSettle();
  }

  testWidgets('too few available questions is an explanatory state', (
    tester,
  ) async {
    final repository = ControlledAssessmentRepository()
      ..questions = [bank.first];
    final c = testContainer(
      repository: repository,
      topics: FakeTopicRepository()..answers = evidence(),
    );
    addTearDown(c.dispose);
    await pumpApp(tester, c, '/progress/practice/start/english');
    await tester.tap(find.text('Start practice'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Practice needs at least 2'), findsOneWidget);
    expect(c.read(practiceControllerProvider), isNull);
  });
  testWidgets(
    'practice question/result/review route flow and return to Progress',
    (tester) async {
      final progress = FakeProgressRepository();
      final c = testContainer(
        progress: progress,
        topics: FakeTopicRepository()..answers = evidence(),
      );
      addTearDown(c.dispose);
      await pumpApp(tester, c, '/progress');
      final launch = find.text('Practice weak topics • English');
      await tester.ensureVisible(launch);
      await tester.tap(launch);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start practice'));
      await tester.pumpAndSettle();
      expect(find.text('English practice'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('en_1_1')));
      await tester.ensureVisible(find.text('Next'));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Finish practice'));
      await tester.tap(find.text('Finish practice'));
      await tester.pumpAndSettle();
      expect(find.text('Score: 1 / 3 points'), findsOneWidget);
      expect(find.text('Skipped: 1'), findsOneWidget);
      expect(find.text('Saved to your history'), findsNothing);
      await tester.ensureVisible(find.text('Review answers'));
      await tester.tap(find.text('Review answers'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Practice'), findsOneWidget);
      await tester.ensureVisible(find.text('Back to result'));
      await tester.tap(find.text('Back to result'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Back to Progress'));
      await tester.tap(find.text('Back to Progress'));
      await tester.pumpAndSettle();
      expect(find.text('Weak Areas'), findsOneWidget);
      expect(progress.saveCalls, 0);
    },
  );
  testWidgets(
    'loading, retryable error, insufficient data and missing session',
    (tester) async {
      final topics = FakeTopicRepository();
      final pending = Completer<List<TopicAnswer>>();
      topics.pending['user-a'] = pending;
      final c = testContainer(topics: topics);
      addTearDown(c.dispose);
      await pumpApp(tester, c, '/progress/practice/start/english');
      await tester.tap(find.text('Start practice'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsWidgets);
      pending.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Unable to load practice.'), findsOneWidget);
      topics.pending.clear();
      await tester.tap(find.text('Start practice'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No confirmed weak topics'), findsOneWidget);
      c.read(appRouterProvider).go('/progress/practice/result');
      await tester.pumpAndSettle();
      expect(find.text('Back to Progress'), findsOneWidget);
    },
  );
  testWidgets('buttons obey category filter and evidence threshold', (
    tester,
  ) async {
    final c = testContainer(
      topics: FakeTopicRepository()..answers = evidence(),
    );
    addTearDown(c.dispose);
    await pumpApp(tester, c, '/progress');
    expect(find.text('Practice weak topics • English'), findsOneWidget);
    c.read(progressCategoryProvider.notifier).select('kazakh');
    await tester.pumpAndSettle();
    expect(find.textContaining('Practice weak topics'), findsNothing);
    c.read(progressCategoryProvider.notifier).select(null);
    await tester.pumpAndSettle();
    expect(find.text('Practice weak topics • English'), findsOneWidget);
  });
}

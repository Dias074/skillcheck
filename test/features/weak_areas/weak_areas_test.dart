import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillcheck/features/weak_areas/domain/topic_performance.dart';
import 'package:skillcheck/features/weak_areas/application/weak_areas_providers.dart';
import 'package:skillcheck/features/progress/application/progress_providers.dart';
import 'package:skillcheck/features/auth/domain/auth_repository.dart';
import 'package:skillcheck/features/assessments/application/assessment_controller.dart';

import '../../fixtures/fake_repositories.dart';

TopicAnswer answer(
  int i, {
  bool correct = false,
  bool answered = true,
  int points = 1,
  String user = 'user-a',
  String category = 'english',
  String topic = 'grammar',
  String? question,
  String? attempt,
}) => TopicAnswer(
  userId: user,
  attemptId: attempt ?? 'attempt-${i ~/ 2}',
  questionId: question ?? 'q${i % 2}',
  categoryId: category,
  categoryName: category,
  topicId: '$category-$topic',
  topicName: topic,
  answered: answered,
  isCorrect: correct,
  pointsEarned: correct ? points : 0,
  maxPoints: points,
);

void main() {
  const calculator = TopicPerformanceCalculator();
  const policy = WeakAreaPolicy();
  TopicPerformance calculate(List<TopicAnswer> rows) =>
      calculator.calculate(rows, userId: 'user-a').single;
  test('weak topic uses earned/available points, not correct-answer ratio', () {
    final result = calculate([
      for (var i = 0; i < 6; i++)
        answer(i, correct: i < 3, points: i < 3 ? 1 : 2),
    ]);
    expect(result.answered, 6);
    expect(result.correct, 3);
    expect(result.incorrect, 3);
    expect(result.pointsEarned, 3);
    expect(result.availablePoints, 9);
    expect(result.percentage, closeTo(100 / 3, 0.00001));
    expect(result.attemptCount, 3);
    expect(policy.classify(result), TopicStatus.weak);
  });
  test('exact threshold and strong topic are satisfactory', () {
    final boundary = calculate([
      for (var i = 0; i < 5; i++) answer(i, correct: i < 3),
    ]);
    expect(boundary.percentage, 60);
    expect(policy.classify(boundary), TopicStatus.satisfactory);
    expect(
      policy.classify(
        calculate([for (var i = 0; i < 6; i++) answer(i, correct: true)]),
      ),
      TopicStatus.satisfactory,
    );
    expect(
      const WeakAreaPolicy(threshold: 70).classify(boundary),
      TopicStatus.weak,
    );
  });
  test(
    'few answers, one attempt or repeated single question are insufficient',
    () {
      expect(
        policy.classify(calculate([answer(0)])),
        TopicStatus.insufficientData,
      );
      expect(
        policy.classify(
          calculate([
            for (var i = 0; i < 6; i++)
              answer(i, attempt: 'a', question: 'q$i'),
          ]),
        ),
        TopicStatus.insufficientData,
      );
      expect(
        policy.classify(
          calculate([
            for (var i = 0; i < 6; i++)
              answer(i, attempt: 'a$i', question: 'same'),
          ]),
        ),
        TopicStatus.insufficientData,
      );
    },
  );
  test('skips add topic appearances, but not denominator or evidence', () {
    final result = calculate([
      answer(0, correct: true, points: 2),
      answer(1),
      answer(2, answered: false, points: 9),
    ]);
    expect(result.answered, 2);
    expect(result.skipped, 1);
    expect(result.availablePoints, 3);
    expect(result.percentage, closeTo(200 / 3, 0.00001));
    expect(result.attemptCount, 2);
    expect(result.answeredAttemptCount, 1);
    final skipped = calculate([answer(0, answered: false)]);
    expect(skipped.percentage, isNull);
    expect(policy.classify(skipped), TopicStatus.insufficientData);
  });
  test('multiple topics, category filter, user isolation, duplicates and empty data', () {
    final rows = [
      answer(0),
      answer(1),
      answer(0),
      answer(2, topic: 'vocabulary'),
      answer(4, category: 'kazakh'),
      answer(5, user: 'user-b'),
    ];
    final all = calculator.calculate(rows, userId: 'user-a');
    expect(all.length, 3);
    expect(all.first.answered, 2);
    expect(
      calculator
          .calculate(rows, userId: 'user-a', categoryId: 'kazakh')
          .single
          .answered,
      1,
    );
    expect(calculator.calculate(rows, userId: 'nobody'), isEmpty);
    expect(calculator.calculate([], userId: 'user-a'), isEmpty);
  });
  test('changed point metadata is rejected rather than showing misleading percentages', () {
    expect(
      () => calculate([
        const TopicAnswer(
          userId: 'user-a',
          attemptId: 'a',
          questionId: 'q',
          categoryId: 'en',
          categoryName: 'English',
          topicId: 'grammar',
          topicName: 'Grammar',
          answered: true,
          isCorrect: true,
          pointsEarned: 2,
          maxPoints: 1,
        ),
      ]),
      throwsFormatException,
    );
  });
  test('providers clear old data and filter on account switch; ignore late response', () async {
    final auth = FakeAuthRepository();
    final repo = FakeTopicRepository()
      ..pending['user-a'] = Completer<List<TopicAnswer>>();
    final container = testContainer(auth: auth, topics: repo);
    addTearDown(container.dispose);
    addTearDown(auth.dispose);
    container.listen(topicPerformanceProvider, (_, _) {});
    container.read(progressCategoryProvider.notifier).select('english');
    expect(container.read(topicPerformanceProvider).isLoading, true);
    auth.emit(
      const AuthSnapshot(
        user: AuthUser(id: 'user-b', email: 'b@example.test'),
      ),
    );
    expect(container.read(progressCategoryProvider), isNull);
    expect(container.read(topicPerformanceProvider).asData, isNull);
    repo.pending['user-a']!.complete([answer(0)]);
    await container.read(userTopicAnswersProvider('user-b').future);
    await container.pump();
    expect(container.read(topicPerformanceProvider).requireValue, isEmpty);
    await auth.signOut();
    expect(container.read(topicPerformanceProvider).requireValue, isEmpty);
  });
  test(
    'successful save refreshes topic answers and category filter is shared',
    () async {
      final repo = FakeTopicRepository()
        ..answers = [answer(0), answer(1, category: 'kazakh')];
      final container = testContainer(topics: repo);
      addTearDown(container.dispose);
      container.listen(topicPerformanceProvider, (_, _) {});
      await container.read(userTopicAnswersProvider('user-a').future);
      expect(container.read(topicPerformanceProvider).requireValue.length, 2);
      container.read(progressCategoryProvider.notifier).select('kazakh');
      expect(
        container.read(topicPerformanceProvider).requireValue.single.categoryId,
        'kazakh',
      );
      final before = repo.calls;
      final controller = container.read(assessmentControllerProvider.notifier);
      await controller.start('english');
      await controller.submit();
      await container.read(userTopicAnswersProvider('user-a').future);
      expect(repo.calls, before + 1);
    },
  );
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:skillcheck/core/errors/app_failure.dart';
import 'package:skillcheck/features/assessments/application/assessment_controller.dart';
import 'package:skillcheck/features/assessments/domain/models/assessment_result.dart';
import 'package:skillcheck/features/auth/domain/auth_repository.dart';
import 'package:skillcheck/features/progress/domain/assessment_history.dart';
import 'package:skillcheck/features/progress/domain/progress_summary.dart';
import 'package:skillcheck/features/progress/data/progress_mapper.dart';
import 'package:skillcheck/features/progress/application/progress_providers.dart';

import '../../fixtures/fake_repositories.dart';

HistoryAttempt historyAttempt(
  String id, {
  String category = 'english',
  int score = 1,
  int max = 4,
  String user = 'user-a',
  int day = 1,
}) => HistoryAttempt(
  userId: user,
  categoryName: category == 'english' ? 'English' : 'Logic & Reasoning',
  result: AssessmentResult(
    assessmentId: id,
    categoryId: category,
    score: score,
    maxScore: max,
    correctAnswers: score > 0 ? 1 : 0,
    incorrectAnswers: 0,
    unansweredQuestions: score == max ? 0 : 1,
    completedAt: DateTime.utc(2026, 9, day),
  ),
);

void main() {
  test('empty history has zero totals and no chart or categories', () {
    final summary = ProgressSummary([]);
    expect(summary.total, 0);
    expect(summary.averagePercentage, 0);
    expect(summary.categories, isEmpty);
    expect(summary.recentChart, isEmpty);
  });
  test(
    'averages percentages equally, filters categories and sorts newest first',
    () {
      final items = [
        historyAttempt('a'),
        historyAttempt('b', score: 10, max: 10, day: 3),
        historyAttempt('c', category: 'logic', score: 0, day: 2),
      ];
      final summary = ProgressSummary(items);
      expect(summary.averagePercentage, closeTo(125 / 3, 0.00001));
      expect(summary.attempts.map((a) => a.result.assessmentId), [
        'b',
        'c',
        'a',
      ]);
      expect(summary.categories.first.averagePercentage, 62.5);
      final filtered = ProgressSummary(items, categoryId: 'english');
      expect(filtered.total, 2);
      expect(filtered.averagePercentage, 62.5);
      expect(ProgressSummary(items, categoryId: 'kazakh').total, 0);
      expect(items.first.result.assessmentId, 'a'); // input not mutated
    },
  );
  test(
    'chart contains only ten most recent attempts in chronological order',
    () {
      final summary = ProgressSummary([
        for (var i = 1; i <= 12; i++) historyAttempt('$i', day: i),
      ]);
      expect(summary.recentChart.length, 10);
      expect(summary.recentChart.first.result.assessmentId, '3');
      expect(summary.recentChart.last.result.assessmentId, '12');
    },
  );
  test(
    'submission saves all answers, locks edits and coalesces repeated taps',
    () async {
      final repo = FakeProgressRepository()..pendingSave = Completer<void>();
      final container = testContainer(progress: repo);
      addTearDown(container.dispose);
      final controller = container.read(assessmentControllerProvider.notifier);
      await controller.start('english');
      controller.selectAnswer('en_1_1');
      final first = controller.submit();
      final second = controller.submit();
      expect(identical(first, second), isTrue);
      expect(repo.saveCalls, 1);
      expect(container.read(assessmentControllerProvider)!.isSaving, isTrue);
      expect(controller.next, throwsStateError);
      repo.pendingSave!.complete();
      final result = await first;
      await second;
      expect(result.score, 1);
      expect(container.read(assessmentControllerProvider)!.isSaved, isTrue);
      await controller.submit();
      expect(repo.saveCalls, 1);
      final payload = ProgressMapper.submission(repo.submissions.single);
      final answers = payload['p_answers'] as List;
      expect(answers.length, 3);
      expect(answers[0]['is_correct'], true);
      expect(answers[0]['points_earned'], 1);
      expect(answers[1]['selected_option_id'], isNull);
      expect(answers[1]['is_correct'], false);
      expect((payload['p_attempt'] as Map).containsKey('user_id'), false);
    },
  );
  test(
    'lost acknowledgement retries same frozen result without duplicate history',
    () async {
      final repo = FakeProgressRepository()..failAfterSave = true;
      final container = testContainer(progress: repo);
      addTearDown(container.dispose);
      final controller = container.read(assessmentControllerProvider.notifier);
      await controller.start('english');
      final result = await controller.submit();
      final failed = container.read(assessmentControllerProvider)!;
      expect(failed.saveError, isNotNull);
      expect(failed.isSaved, false);
      await expectLater(controller.start('kazakh'), throwsA(isA<AppFailure>()));
      repo.failAfterSave = false;
      expect(identical(await controller.submit(), result), true);
      expect(repo.saved['user-a']!.length, 1);
      expect(
        repo.submissions[0].result.completedAt,
        repo.submissions[1].result.completedAt,
      );
      expect(container.read(assessmentControllerProvider)!.saveError, isNull);
    },
  );
  test('logout during saving cannot resurrect the old assessment', () async {
    final auth = FakeAuthRepository();
    final repo = FakeProgressRepository()..pendingSave = Completer<void>();
    final container = testContainer(auth: auth, progress: repo);
    addTearDown(container.dispose);
    addTearDown(auth.dispose);
    final controller = container.read(assessmentControllerProvider.notifier);
    await controller.start('english');
    final pending = controller.submit();
    await auth.signOut();
    expect(container.read(assessmentControllerProvider), isNull);
    auth.emit(
      const AuthSnapshot(
        user: AuthUser(id: 'user-b', email: 'b@example.test'),
      ),
    );
    expect(container.read(assessmentControllerProvider), isNull);
    repo.pendingSave!.complete();
    await pending;
    expect(container.read(assessmentControllerProvider), isNull);
    expect(repo.saved['user-b'], isNull);
  });
  test(
    'history refreshes after save and survives a fresh provider container',
    () async {
      final repo = FakeProgressRepository();
      final container = testContainer(progress: repo);
      addTearDown(container.dispose);
      final listener = container.listen(progressHistoryProvider, (_, _) {});
      addTearDown(listener.close);
      expect(
        await container.read(userHistoryProvider('user-a').future),
        isEmpty,
      );
      final controller = container.read(assessmentControllerProvider.notifier);
      await controller.start('english');
      await controller.submit();
      expect(
        await container.read(userHistoryProvider('user-a').future),
        hasLength(1),
      );
      final fresh = testContainer(progress: repo);
      addTearDown(fresh.dispose);
      expect(
        await fresh.read(userHistoryProvider('user-a').future),
        hasLength(1),
      );
    },
  );
  test('account switch clears filter and hides old history, including late responses', () async {
    final auth = FakeAuthRepository();
    final repo = FakeProgressRepository();
    repo.pendingFetch['user-a'] = Completer<List<HistoryAttempt>>();
    final container = testContainer(auth: auth, progress: repo);
    addTearDown(container.dispose);
    addTearDown(auth.dispose);
    container.listen(progressHistoryProvider, (_, _) {});
    container.read(progressCategoryProvider.notifier).select('english');
    expect(container.read(progressHistoryProvider).isLoading, true);
    auth.emit(
      const AuthSnapshot(
        user: AuthUser(id: 'user-b', email: 'b@example.test'),
      ),
    );
    expect(container.read(progressCategoryProvider), isNull);
    expect(container.read(progressHistoryProvider).asData, isNull);
    repo.pendingFetch['user-a']!.complete([historyAttempt('a')]);
    await container.read(userHistoryProvider('user-b').future);
    await container.pump();
    expect(container.read(progressHistoryProvider).requireValue, isEmpty);
    await auth.signOut();
    expect(container.read(progressHistoryProvider).requireValue, isEmpty);
  });
  test('mapper rebuilds domain result from server row', () {
    final attempt = ProgressMapper.history({
      'id': 'a',
      'user_id': 'user-a',
      'category_id': 'english',
      'categories': {'name': 'English'},
      'score': 1,
      'max_score': 4,
      'correct_count': 1,
      'incorrect_count': 1,
      'skipped_count': 1,
      'completed_at': '2026-09-28T10:00:00Z',
    });
    expect(attempt.result.percentage, 25);
    expect(attempt.result.totalQuestions, 3);
    expect(attempt.categoryName, 'English');
  });
}

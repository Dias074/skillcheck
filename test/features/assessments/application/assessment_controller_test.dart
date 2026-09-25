import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillcheck/features/assessments/application/assessment_controller.dart';
import 'package:skillcheck/features/assessments/application/assessment_session.dart';
import 'package:skillcheck/features/assessments/data/local/local_question_source.dart';
import 'package:skillcheck/features/assessments/domain/services/assessment_scorer.dart';

void main() {
  late ProviderContainer container;
  late AssessmentController controller;
  final now = DateTime.utc(2026, 9, 25);

  setUp(() {
    container = ProviderContainer(
      overrides: [assessmentClockProvider.overrideWithValue(() => now)],
    );
    controller = container.read(assessmentControllerProvider.notifier);
  });
  tearDown(() => container.dispose());
  AssessmentSession session() => container.read(assessmentControllerProvider)!;

  test(
    'all five datasets create valid assessments with both question types',
    () {
      for (final category in LocalQuestionSource.categories) {
        controller.start(category.id);
        final current = session();
        expect(current.assessment.questions, hasLength(3));
        expect(
          current.assessment.questions.map((q) => q.type).toSet(),
          hasLength(2),
        );
        expect(current.category.id, category.id);
        expect(current.skippedCount, 3);
        expect(current.questionIndex, 0);
        expect(
          current.assessment.questions.every(
            (q) => q.categoryId == category.id,
          ),
          isTrue,
        );
      }
    },
  );

  test('preserves, replaces and clears choices without mutating old state', () {
    controller.start('english');
    final original = session();
    controller.selectAnswer('en_1_0');
    controller.next();
    controller.selectAnswer('en_2_1');
    controller.previous();
    expect(session().selections['en_1'], 'en_1_0');
    controller.selectAnswer('en_1_1');
    expect(session().selections['en_1'], 'en_1_1');
    controller.clearAnswer();
    expect(session().selections.containsKey('en_1'), isFalse);
    expect(session().selections['en_2'], 'en_2_1');
    expect(original.selections, isEmpty);
    expect(() => session().selections.clear(), throwsUnsupportedError);
  });

  test('navigation clamps at boundaries and permits unanswered questions', () {
    controller.start('english');
    controller.previous();
    expect(session().questionIndex, 0);
    controller.next();
    controller.next();
    controller.next();
    expect(session().questionIndex, 2);
    expect(session().progress, 1);
    expect(session().skippedCount, 3);
  });

  test(
    'submission matches domain scorer for a correct, wrong and skipped answer',
    () {
      controller.start('english');
      controller.selectAnswer('en_1_1');
      controller.next();
      controller.selectAnswer('en_2_1');
      controller.next();
      final before = session();
      final expected = const AssessmentScorer().score(
        assessment: before.assessment,
        answers: before.answers,
        completedAt: now,
      );
      final actual = controller.submit();
      expect(actual.score, expected.score);
      expect(actual.percentage, expected.percentage);
      expect(actual.correctAnswers, 1);
      expect(actual.incorrectAnswers, 1);
      expect(actual.unansweredQuestions, 1);
      expect(session().review.map((r) => r.status), [
        ReviewStatus.correct,
        ReviewStatus.incorrect,
        ReviewStatus.skipped,
      ]);
      expect(session().review.first.selectedText, 'goes');
      expect(session().review[1].correctText, 'True');
      expect(session().review.last.selectedText, 'Skipped');
    },
  );

  test('all skipped submission is allowed and review stays locked until submission', () {
    controller.start('english');
    expect(() => session().review, throwsStateError);
    final result = controller.submit();
    expect(result.score, 0);
    expect(result.unansweredQuestions, 3);
    expect(
      session().review.every((r) => r.status == ReviewStatus.skipped),
      isTrue,
    );
  });

  test('all correct answers earn full marks in every category', () {
    for (final category in LocalQuestionSource.categories) {
      controller.start(category.id);
      for (var i = 0; i < 3; i++) {
        controller.selectAnswer(session().currentQuestion.correctOptionId);
        controller.next();
      }
      expect(controller.submit().percentage, 100);
    }
  });

  test('submission is idempotent and blocks subsequent edits', () {
    controller.start('english');
    final result = controller.submit();
    expect(identical(controller.submit(), result), isTrue);
    expect(() => controller.selectAnswer('en_1_1'), throwsStateError);
    expect(controller.clearAnswer, throwsStateError);
    expect(controller.next, throwsStateError);
    expect(controller.previous, throwsStateError);
  });

  test('new attempt resets answers, index and result and gets a new ID', () {
    controller.start('english');
    final id = session().assessment.id;
    controller.selectAnswer('en_1_1');
    controller.next();
    controller.submit();
    controller.start('english');
    expect(session().assessment.id, isNot(id));
    expect(session().selections, isEmpty);
    expect(session().result, isNull);
    expect(session().questionIndex, 0);
  });

  test('invalid inputs cannot corrupt a valid session', () {
    expect(controller.submit, throwsStateError);
    controller.start('english');
    final original = session();
    expect(() => controller.start('missing'), throwsArgumentError);
    expect(() => controller.selectAnswer('en_2_0'), throwsArgumentError);
    expect(identical(session(), original), isTrue);
  });

  test('a fresh app container has no stored attempt or result', () {
    controller.start('english');
    controller.submit();
    final fresh = ProviderContainer();
    addTearDown(fresh.dispose);
    expect(fresh.read(assessmentControllerProvider), isNull);
  });
}

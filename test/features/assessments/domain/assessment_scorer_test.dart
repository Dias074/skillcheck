import 'package:flutter_test/flutter_test.dart';
import 'package:skillcheck/features/assessments/domain/models/assessment.dart';
import 'package:skillcheck/features/assessments/domain/models/assessment_answer.dart';
import 'package:skillcheck/features/assessments/domain/models/question.dart';
import 'package:skillcheck/features/assessments/domain/models/question_option.dart';
import 'package:skillcheck/features/assessments/domain/services/assessment_scorer.dart';

void main() {
  const scorer = AssessmentScorer();
  final start = DateTime.utc(2026, 9, 24, 10);
  final finish = start.add(const Duration(minutes: 5));

  Question question(
    String id, {
    int points = 1,
    QuestionType type = QuestionType.multipleChoice,
  }) => Question(
    id: id,
    categoryId: 'programming',
    topicId: 'dart',
    questionText: 'Is Dart a programming language?',
    type: type,
    difficulty: QuestionDifficulty.easy,
    options: [
      QuestionOption(id: '${id}_yes', text: 'True'),
      QuestionOption(id: '${id}_no', text: 'False'),
    ],
    correctOptionId: '${id}_yes',
    explanation: 'Dart is a programming language.',
    points: points,
  );

  Assessment assessment(List<Question> questions) => Assessment(
    id: 'attempt',
    categoryId: 'programming',
    questions: questions,
    startedAt: start,
  );

  AssessmentAnswer answer(
    String id,
    String? option, {
    String assessmentId = 'attempt',
  }) => AssessmentAnswer(
    assessmentId: assessmentId,
    questionId: id,
    selectedOptionId: option,
  );

  test('both supported question types earn full points', () {
    final attempt = assessment([
      question('one'),
      question('two', type: QuestionType.trueFalse),
    ]);
    final result = scorer.score(
      assessment: attempt,
      answers: [answer('one', 'one_yes'), answer('two', 'two_yes')],
      completedAt: finish,
    );
    expect(result.score, 2);
    expect(result.maxScore, 2);
    expect(result.percentage, 100);
    expect(result.correctAnswers, 2);
    expect(result.incorrectAnswers, 0);
    expect(result.unansweredQuestions, 0);
    expect(result.totalQuestions, 2);
    expect(result.assessmentId, attempt.id);
    expect(result.categoryId, attempt.categoryId);
    expect(result.completedAt, finish);
  });

  test('all incorrect answers score zero without negative marking', () {
    final result = scorer.score(
      assessment: assessment([question('one'), question('two')]),
      answers: [answer('one', 'one_no'), answer('two', 'two_no')],
      completedAt: finish,
    );
    expect(result.score, 0);
    expect(result.percentage, 0);
    expect(result.correctAnswers, 0);
    expect(result.incorrectAnswers, 2);
    expect(result.unansweredQuestions, 0);
  });

  test('weights, incorrect answers and skips use the full denominator', () {
    final result = scorer.score(
      assessment: assessment([
        question('one', points: 5),
        question('two', points: 2),
        question('three', points: 2),
        question('four'),
      ]),
      answers: [
        answer('three', null),
        answer('two', 'two_no'),
        answer('one', 'one_yes'),
      ],
      completedAt: finish,
    );
    expect(result.score, 5);
    expect(result.maxScore, 10);
    expect(result.percentage, 50);
    expect(result.correctAnswers, 1);
    expect(result.incorrectAnswers, 1);
    expect(result.unansweredQuestions, 2);
    expect(result.totalQuestions, 4);
  });

  test('no submitted answers counts every question as unanswered', () {
    final result = scorer.score(
      assessment: assessment([question('one'), question('two')]),
      answers: [],
      completedAt: finish,
    );
    expect(result.percentage, 0);
    expect(result.incorrectAnswers, 0);
    expect(result.unansweredQuestions, 2);
  });

  test('percentage is not rounded in the domain', () {
    final result = scorer.score(
      assessment: assessment([
        question('one'),
        question('two'),
        question('three'),
      ]),
      answers: [answer('one', 'one_yes')],
      completedAt: finish,
    );
    expect(result.percentage, closeTo(100 / 3, 0.0000001));
  });

  test('answer order does not affect scoring and inputs are not modified', () {
    final attempt = assessment([question('one'), question('two', points: 3)]);
    final answers = [answer('one', 'one_no'), answer('two', 'two_yes')];
    final original = List<AssessmentAnswer>.of(answers);
    final first = scorer.score(
      assessment: attempt,
      answers: answers,
      completedAt: finish,
    );
    final second = scorer.score(
      assessment: attempt,
      answers: answers.reversed.toList(),
      completedAt: finish,
    );
    expect(second.score, first.score);
    expect(second.correctAnswers, first.correctAnswers);
    expect(second.incorrectAnswers, first.incorrectAnswers);
    expect(answers, orderedEquals(original));
    expect(attempt.questions.map((q) => q.id), ['one', 'two']);
  });

  for (final entry in <String, List<AssessmentAnswer>>{
    'duplicate answer': [answer('one', 'one_yes'), answer('one', 'one_no')],
    'duplicate skipped answer': [answer('one', null), answer('one', null)],
    'foreign assessment': [answer('one', 'one_yes', assessmentId: 'another')],
    'unknown question': [answer('missing', null)],
    'unknown option': [answer('one', 'missing')],
    'option from another question': [answer('one', 'two_yes')],
  }.entries) {
    test('rejects ${entry.key}', () {
      expect(
        () => scorer.score(
          assessment: assessment([question('one'), question('two')]),
          answers: entry.value,
          completedAt: finish,
        ),
        throwsArgumentError,
      );
    });
  }

  test('rejects completion before start', () {
    expect(
      () => scorer.score(
        assessment: assessment([question('one')]),
        answers: [],
        completedAt: start.subtract(const Duration(seconds: 1)),
      ),
      throwsArgumentError,
    );
  });

  test('allows completion at the same instant as start', () {
    final result = scorer.score(
      assessment: assessment([question('one')]),
      answers: [],
      completedAt: start,
    );
    expect(result.completedAt, start);
  });
}

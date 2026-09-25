import 'package:flutter_test/flutter_test.dart';
import 'package:skillcheck/features/assessments/domain/models/assessment.dart';
import 'package:skillcheck/features/assessments/domain/models/assessment_result.dart';
import 'package:skillcheck/features/assessments/domain/models/question.dart';
import 'package:skillcheck/features/assessments/domain/models/question_option.dart';

void main() {
  const options = [
    QuestionOption(id: 'yes', text: 'True'),
    QuestionOption(id: 'no', text: 'False'),
  ];
  final startedAt = DateTime.utc(2026, 9, 24);

  Question question({
    String id = 'question',
    String categoryId = 'programming',
    int points = 1,
    QuestionType type = QuestionType.multipleChoice,
    List<QuestionOption> choices = options,
    String correct = 'yes',
    String text = 'Is Dart a programming language?',
  }) => Question(
    id: id,
    categoryId: categoryId,
    topicId: 'dart',
    questionText: text,
    type: type,
    difficulty: QuestionDifficulty.easy,
    options: choices,
    correctOptionId: correct,
    explanation: 'Dart is a programming language.',
    points: points,
  );

  Assessment assessment(List<Question> questions) => Assessment(
    id: 'attempt',
    categoryId: 'programming',
    questions: questions,
    startedAt: startedAt,
  );

  test('question copies and protects its option list', () {
    final mutable = [...options];
    final item = question(choices: mutable);
    mutable.clear();
    expect(item.options, hasLength(2));
    expect(() => item.options.clear(), throwsUnsupportedError);
  });

  test('assessment copies and protects its question snapshot', () {
    final mutable = [question()];
    final attempt = assessment(mutable);
    mutable.clear();
    expect(attempt.questions, hasLength(1));
    expect(() => attempt.questions.clear(), throwsUnsupportedError);
  });

  test('rejects an empty assessment rather than divide by zero', () {
    expect(() => assessment([]), throwsArgumentError);
  });

  test('rejects repeated question IDs', () {
    expect(() => assessment([question(), question()]), throwsArgumentError);
  });

  test('rejects questions from another category', () {
    expect(
      () => assessment([question(categoryId: 'english')]),
      throwsArgumentError,
    );
  });

  for (final points in [0, -1]) {
    test('rejects nonpositive question points: $points', () {
      expect(() => question(points: points), throwsArgumentError);
    });
  }

  test('rejects an answer key outside the available options', () {
    expect(() => question(correct: 'missing'), throwsArgumentError);
  });

  test('rejects repeated option IDs', () {
    expect(
      () => question(choices: [options.first, options.first]),
      throwsArgumentError,
    );
  });

  test('rejects blank option ID or text', () {
    expect(
      () => question(
        choices: [
          options.first,
          const QuestionOption(id: ' ', text: 'False'),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => question(
        choices: [
          options.first,
          const QuestionOption(id: 'no', text: ' '),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('rejects blank question ID or text', () {
    expect(() => question(id: ' '), throwsArgumentError);
    expect(() => question(text: ' '), throwsArgumentError);
  });

  test('multiple choice requires at least two choices', () {
    expect(() => question(choices: []), throwsArgumentError);
    expect(() => question(choices: [options.first]), throwsArgumentError);
  });

  test('true/false requires exactly two choices', () {
    expect(
      () => question(type: QuestionType.trueFalse, choices: [options.first]),
      throwsArgumentError,
    );
    expect(
      () => question(
        type: QuestionType.trueFalse,
        choices: [
          ...options,
          const QuestionOption(id: 'maybe', text: 'Maybe'),
        ],
      ),
      throwsArgumentError,
    );
    expect(question(type: QuestionType.trueFalse).options, hasLength(2));
  });

  test('multiple choice accepts more than two choices', () {
    expect(
      question(
        choices: [
          ...options,
          const QuestionOption(id: 'maybe', text: 'Maybe'),
        ],
      ).options,
      hasLength(3),
    );
  });

  AssessmentResult result({
    int score = 1,
    int maxScore = 2,
    int correct = 1,
    int incorrect = 1,
    int unanswered = 0,
  }) => AssessmentResult(
    assessmentId: 'attempt',
    categoryId: 'programming',
    score: score,
    maxScore: maxScore,
    correctAnswers: correct,
    incorrectAnswers: incorrect,
    unansweredQuestions: unanswered,
    completedAt: startedAt,
  );

  test('result rejects invalid bounds and answer counts', () {
    expect(() => result(maxScore: 0), throwsArgumentError);
    expect(() => result(score: -1), throwsArgumentError);
    expect(() => result(score: 3), throwsArgumentError);
    expect(() => result(correct: -1), throwsArgumentError);
    expect(() => result(incorrect: -1), throwsArgumentError);
    expect(() => result(unanswered: -1), throwsArgumentError);
    expect(() => result(correct: 0, incorrect: 0), throwsArgumentError);
  });

  test('result rejects contradictory point totals', () {
    expect(() => result(correct: 0), throwsArgumentError);
    expect(() => result(score: 0), throwsArgumentError);
    expect(() => result(score: 2), throwsArgumentError);
    expect(() => result(incorrect: 0), throwsArgumentError);
    expect(() => result(maxScore: 1), throwsArgumentError);
  });
}

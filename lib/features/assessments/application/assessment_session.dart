import '../domain/models/assessment.dart';
import '../domain/models/assessment_answer.dart';
import '../domain/models/assessment_result.dart';
import '../domain/models/category.dart';
import '../domain/models/question.dart';

enum ReviewStatus { correct, incorrect, skipped }

/// Read-only review data; available only once the controller submits the attempt.
class AnswerReview {
  const AnswerReview({required this.question, required this.selectedOptionId});

  final Question question;
  final String? selectedOptionId;

  String get selectedText => selectedOptionId == null
      ? 'Skipped'
      : question.options
            .firstWhere((option) => option.id == selectedOptionId)
            .text;
  String get correctText => question.options
      .firstWhere((option) => option.id == question.correctOptionId)
      .text;
  ReviewStatus get status => selectedOptionId == null
      ? ReviewStatus.skipped
      : selectedOptionId == question.correctOptionId
      ? ReviewStatus.correct
      : ReviewStatus.incorrect;
}

/// One in-memory attempt, not a history of attempts.
class AssessmentSession {
  AssessmentSession({
    required this.category,
    required this.assessment,
    this.questionIndex = 0,
    Map<String, String> selections = const {},
    this.result,
  }) : selections = Map.unmodifiable(selections);

  final Category category;
  final Assessment assessment;
  final int questionIndex;
  final Map<String, String> selections;
  final AssessmentResult? result;

  Question get currentQuestion => assessment.questions[questionIndex];
  bool get isFirst => questionIndex == 0;
  bool get isLast => questionIndex == assessment.questions.length - 1;
  int get skippedCount => assessment.questions.length - selections.length;
  double get progress => (questionIndex + 1) / assessment.questions.length;

  List<AssessmentAnswer> get answers => [
    for (final question in assessment.questions)
      AssessmentAnswer(
        assessmentId: assessment.id,
        questionId: question.id,
        selectedOptionId: selections[question.id],
      ),
  ];

  List<AnswerReview> get review {
    if (result == null) {
      throw StateError('Submit the assessment before reviewing answers.');
    }
    return List.unmodifiable([
      for (final question in assessment.questions)
        AnswerReview(
          question: question,
          selectedOptionId: selections[question.id],
        ),
    ]);
  }

  AssessmentSession copyWith({
    int? questionIndex,
    Map<String, String>? selections,
    AssessmentResult? result,
  }) => AssessmentSession(
    category: category,
    assessment: assessment,
    questionIndex: questionIndex ?? this.questionIndex,
    selections: selections ?? this.selections,
    result: result ?? this.result,
  );
}

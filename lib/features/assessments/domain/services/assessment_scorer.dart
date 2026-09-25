import '../models/assessment.dart';
import '../models/assessment_answer.dart';
import '../models/assessment_result.dart';

/// Pure calculation: no Flutter, network, storage or implicit system clock.
class AssessmentScorer {
  const AssessmentScorer();

  AssessmentResult score({
    required Assessment assessment,
    required List<AssessmentAnswer> answers,
    required DateTime completedAt,
  }) {
    if (completedAt.isBefore(assessment.startedAt)) {
      throw ArgumentError(
        'Completion cannot be before the assessment started.',
      );
    }
    final questionsById = {
      for (final question in assessment.questions) question.id: question,
    };
    final answersByQuestion = <String, AssessmentAnswer>{};
    for (final answer in answers) {
      if (answer.assessmentId != assessment.id) {
        throw ArgumentError('Answer belongs to another assessment.');
      }
      final question = questionsById[answer.questionId];
      if (question == null) {
        throw ArgumentError(
          'Answer refers to a question outside this assessment.',
        );
      }
      if (answersByQuestion.containsKey(answer.questionId)) {
        throw ArgumentError('Submit only one answer per question.');
      }
      if (answer.selectedOptionId != null &&
          !question.options.any(
            (option) => option.id == answer.selectedOptionId,
          )) {
        throw ArgumentError('Selected option does not belong to the question.');
      }
      answersByQuestion[answer.questionId] = answer;
    }

    var earnedPoints = 0;
    var maxPoints = 0;
    var correct = 0;
    var incorrect = 0;
    var unanswered = 0;
    for (final question in assessment.questions) {
      maxPoints += question.points;
      final selected = answersByQuestion[question.id]?.selectedOptionId;
      if (selected == null) {
        unanswered++;
      } else if (selected == question.correctOptionId) {
        correct++;
        earnedPoints += question.points;
      } else {
        incorrect++;
      }
    }

    return AssessmentResult(
      assessmentId: assessment.id,
      categoryId: assessment.categoryId,
      score: earnedPoints,
      maxScore: maxPoints,
      correctAnswers: correct,
      incorrectAnswers: incorrect,
      unansweredQuestions: unanswered,
      completedAt: completedAt,
    );
  }
}

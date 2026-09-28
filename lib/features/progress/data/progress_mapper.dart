import '../../assessments/domain/models/assessment_result.dart';
import '../domain/assessment_history.dart';

class ProgressMapper {
  static Map<String, dynamic> submission(CompletedAssessment completed) {
    final result = completed.result;
    final selected = {
      for (final a in completed.answers) a.questionId: a.selectedOptionId,
    };
    return {
      'p_attempt': {
        'id': result.assessmentId,
        'category_id': result.categoryId,
        'score': result.score,
        'max_score': result.maxScore,
        'correct_count': result.correctAnswers,
        'incorrect_count': result.incorrectAnswers,
        'skipped_count': result.unansweredQuestions,
        'started_at': completed.assessment.startedAt.toUtc().toIso8601String(),
        'completed_at': result.completedAt.toUtc().toIso8601String(),
      },
      // Per-answer metadata uses the frozen question snapshot; aggregate scoring
      // remains exclusively in AssessmentScorer.
      'p_answers': [
        for (final q in completed.assessment.questions)
          {
            'question_id': q.id,
            'selected_option_id': selected[q.id],
            'is_correct': selected[q.id] == q.correctOptionId,
            'points_earned': selected[q.id] == q.correctOptionId ? q.points : 0,
          },
      ],
    };
  }

  static HistoryAttempt history(Map<String, dynamic> row) => HistoryAttempt(
    userId: row['user_id'] as String,
    categoryName: (row['categories'] as Map<String, dynamic>)['name'] as String,
    result: AssessmentResult(
      assessmentId: row['id'] as String,
      categoryId: row['category_id'] as String,
      score: row['score'] as int,
      maxScore: row['max_score'] as int,
      correctAnswers: row['correct_count'] as int,
      incorrectAnswers: row['incorrect_count'] as int,
      unansweredQuestions: row['skipped_count'] as int,
      completedAt: DateTime.parse(row['completed_at'] as String),
    ),
  );
}

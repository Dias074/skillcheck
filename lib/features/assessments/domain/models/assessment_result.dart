/// Aggregate score produced by AssessmentScorer.
class AssessmentResult {
  AssessmentResult({
    required this.assessmentId,
    required this.categoryId,
    required this.score,
    required this.maxScore,
    required this.correctAnswers,
    required this.incorrectAnswers,
    required this.unansweredQuestions,
    required this.completedAt,
  }) {
    if (assessmentId.trim().isEmpty || categoryId.trim().isEmpty) {
      throw ArgumentError('Result identifiers must not be blank.');
    }
    if (maxScore <= 0 || score < 0 || score > maxScore) {
      throw ArgumentError(
        'Score must be between zero and a positive maxScore.',
      );
    }
    if (correctAnswers < 0 ||
        incorrectAnswers < 0 ||
        unansweredQuestions < 0 ||
        totalQuestions == 0) {
      throw ArgumentError(
        'Counts must be nonnegative and include at least one question.',
      );
    }
    if ((correctAnswers == 0 && score != 0) ||
        (correctAnswers > 0 && score < correctAnswers) ||
        maxScore < totalQuestions ||
        maxScore - score < incorrectAnswers + unansweredQuestions ||
        (correctAnswers == totalQuestions && score != maxScore)) {
      throw ArgumentError('Score and answer counts are inconsistent.');
    }
  }

  final String assessmentId;
  final String categoryId;
  final int score;
  final int maxScore;
  final int correctAnswers;
  final int incorrectAnswers;
  final int unansweredQuestions;
  final DateTime completedAt;

  int get totalQuestions =>
      correctAnswers + incorrectAnswers + unansweredQuestions;

  /// Weighted by question points. Leave rounding to the presentation layer.
  double get percentage => score / maxScore * 100;
}

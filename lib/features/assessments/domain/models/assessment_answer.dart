/// A user's selection. Null means explicitly skipped.
/// Correctness is calculated from the question, never trusted from the caller.
class AssessmentAnswer {
  const AssessmentAnswer({
    required this.assessmentId,
    required this.questionId,
    required this.selectedOptionId,
  });

  final String assessmentId;
  final String questionId;
  final String? selectedOptionId;
}

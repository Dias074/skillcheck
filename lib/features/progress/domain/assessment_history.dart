import '../../assessments/domain/models/assessment.dart';
import '../../assessments/domain/models/assessment_answer.dart';
import '../../assessments/domain/models/assessment_result.dart';

/// Frozen submission retained in memory until the server acknowledges it.
class CompletedAssessment {
  CompletedAssessment({
    required this.assessment,
    required this.result,
    required List<AssessmentAnswer> answers,
  }) : answers = List.unmodifiable(answers);
  final Assessment assessment;
  final AssessmentResult result;
  final List<AssessmentAnswer> answers;
}

class HistoryAttempt {
  const HistoryAttempt({
    required this.userId,
    required this.categoryName,
    required this.result,
  });
  final String userId;
  final String categoryName;
  final AssessmentResult result;
}

abstract interface class ProgressRepository {
  Future<void> saveAttempt(String userId, CompletedAssessment submission);
  Future<List<HistoryAttempt>> fetchHistory(String userId);
}

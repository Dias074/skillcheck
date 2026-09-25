import 'question.dart';

/// A single attempt with a fixed question snapshot.
/// Keeping the snapshot prevents later question-bank changes from changing a score.
class Assessment {
  Assessment({
    required this.id,
    required this.categoryId,
    required List<Question> questions,
    required this.startedAt,
  }) : questions = List.unmodifiable(questions) {
    if (id.trim().isEmpty || categoryId.trim().isEmpty) {
      throw ArgumentError('Assessment and category IDs must not be blank.');
    }
    if (questions.isEmpty) {
      throw ArgumentError('An assessment must contain at least one question.');
    }
    final questionIds = <String>{};
    for (final question in questions) {
      if (question.categoryId != categoryId) {
        throw ArgumentError(
          'All questions must belong to the assessment category.',
        );
      }
      if (!questionIds.add(question.id)) {
        throw ArgumentError(
          'Question IDs must be unique within an assessment.',
        );
      }
    }
  }

  final String id;
  final String categoryId;
  final List<Question> questions;
  final DateTime startedAt;
}

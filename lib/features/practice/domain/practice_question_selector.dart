import '../../assessments/domain/models/question.dart';
import '../../weak_areas/domain/topic_performance.dart';

/// Expected lack of evidence/content, separate from a network failure.
class PracticeUnavailable implements Exception {
  const PracticeUnavailable(this.message);
  final String message;
}

class PracticeQuestionSelector {
  const PracticeQuestionSelector();

  /// Round-robin across weak topics, weakest first; stable question ID order.
  /// Reuses bank questions, without repeats or unrelated fallback questions.
  List<Question> select({
    required String categoryId,
    required List<TopicPerformance> topics,
    required List<Question> questions,
    required WeakAreaPolicy policy,
  }) {
    final weak =
        topics
            .where(
              (t) =>
                  t.categoryId == categoryId &&
                  policy.classify(t) == TopicStatus.weak,
            )
            .toList()
          ..sort((a, b) {
            final score = a.percentage!.compareTo(b.percentage!);
            return score != 0 ? score : a.topicId.compareTo(b.topicId);
          });
    if (weak.isEmpty) {
      throw const PracticeUnavailable(
        'No confirmed weak topics in this category yet. Complete regular assessments to build enough evidence.',
      );
    }
    final seen = <String>{};
    final groups = [
      for (final topic in weak)
        questions
            .where(
              (q) =>
                  q.categoryId == categoryId &&
                  q.topicId == topic.topicId &&
                  seen.add(q.id),
            )
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id)),
    ];
    final selected = <Question>[];
    for (var index = 0; selected.length < 5; index++) {
      var added = false;
      for (final group in groups) {
        if (index < group.length && selected.length < 5) {
          selected.add(group[index]);
          added = true;
        }
      }
      if (!added) break;
    }
    if (selected.length < 2) {
      throw const PracticeUnavailable(
        'Practice needs at least 2 different questions from your weak topics. There are not enough available yet. You can return to Progress or take a regular assessment.',
      );
    }
    return List.unmodifiable(selected);
  }
}

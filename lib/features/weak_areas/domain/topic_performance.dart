/// One persisted answer enriched with the referenced question's metadata.
class TopicAnswer {
  const TopicAnswer({
    required this.userId,
    required this.attemptId,
    required this.questionId,
    required this.categoryId,
    required this.categoryName,
    required this.topicId,
    required this.topicName,
    required this.answered,
    required this.isCorrect,
    required this.pointsEarned,
    required this.maxPoints,
  });
  final String userId,
      attemptId,
      questionId,
      categoryId,
      categoryName,
      topicId,
      topicName;
  final bool answered, isCorrect;
  final int pointsEarned, maxPoints;
}

enum TopicStatus { insufficientData, weak, satisfactory }

class TopicPerformance {
  TopicPerformance({
    required this.categoryId,
    required this.categoryName,
    required this.topicId,
    required this.topicName,
    required this.answered,
    required this.correct,
    required this.incorrect,
    required this.skipped,
    required this.pointsEarned,
    required this.availablePoints,
    required this.attemptCount,
    required this.answeredAttemptCount,
    required this.distinctQuestions,
  });
  final String categoryId, categoryName, topicId, topicName;
  final int answered,
      correct,
      incorrect,
      skipped,
      pointsEarned,
      availablePoints;
  final int attemptCount, answeredAttemptCount, distinctQuestions;
  double? get percentage =>
      availablePoints == 0 ? null : pointsEarned / availablePoints * 100;
}

/// A replaceable domain policy: the UI does not decide whether a topic is weak.
class WeakAreaPolicy {
  const WeakAreaPolicy({
    this.minimumAnswers = 5,
    this.minimumAttempts = 2,
    this.minimumQuestions = 2,
    this.threshold = 60,
  }) : assert(minimumAnswers > 0),
       assert(minimumAttempts > 0),
       assert(minimumQuestions > 0),
       assert(threshold > 0 && threshold <= 100);
  final int minimumAnswers, minimumAttempts, minimumQuestions;
  final double threshold;
  TopicStatus classify(TopicPerformance topic) {
    if (topic.answered < minimumAnswers ||
        topic.answeredAttemptCount < minimumAttempts ||
        topic.distinctQuestions < minimumQuestions ||
        topic.percentage == null) {
      return TopicStatus.insufficientData;
    }
    return topic.percentage! < threshold
        ? TopicStatus.weak
        : TopicStatus.satisfactory;
  }
}

class TopicPerformanceCalculator {
  const TopicPerformanceCalculator();
  List<TopicPerformance> calculate(
    List<TopicAnswer> answers, {
    required String userId,
    String? categoryId,
  }) {
    final groups = <String, List<TopicAnswer>>{};
    final seen = <(String, String)>{};
    for (final answer in answers) {
      if (answer.userId != userId ||
          (categoryId != null && answer.categoryId != categoryId)) {
        continue;
      }
      if (!seen.add((answer.attemptId, answer.questionId))) continue;
      if (answer.maxPoints <= 0 ||
          answer.pointsEarned < 0 ||
          answer.pointsEarned > answer.maxPoints ||
          (!answer.answered &&
              (answer.isCorrect || answer.pointsEarned != 0)) ||
          (!answer.isCorrect && answer.pointsEarned != 0) ||
          (answer.isCorrect && answer.pointsEarned != answer.maxPoints)) {
        throw const FormatException('Inconsistent topic answer data');
      }
      groups.putIfAbsent(answer.topicId, () => []).add(answer);
    }
    return [for (final rows in groups.values) _aggregate(rows)]..sort((a, b) {
      final category = a.categoryName.compareTo(b.categoryName);
      return category != 0 ? category : a.topicName.compareTo(b.topicName);
    });
  }

  TopicPerformance _aggregate(List<TopicAnswer> rows) {
    final first = rows.first;
    final answered = rows.where((a) => a.answered).toList();
    final correct = answered.where((a) => a.isCorrect).length;
    return TopicPerformance(
      categoryId: first.categoryId,
      categoryName: first.categoryName,
      topicId: first.topicId,
      topicName: first.topicName,
      answered: answered.length,
      correct: correct,
      incorrect: answered.length - correct,
      skipped: rows.length - answered.length,
      pointsEarned: answered.fold(0, (sum, a) => sum + a.pointsEarned),
      availablePoints: answered.fold(0, (sum, a) => sum + a.maxPoints),
      attemptCount: rows.map((a) => a.attemptId).toSet().length,
      answeredAttemptCount: answered.map((a) => a.attemptId).toSet().length,
      distinctQuestions: answered.map((a) => a.questionId).toSet().length,
    );
  }
}

abstract interface class TopicPerformanceRepository {
  Future<List<TopicAnswer>> fetchAnswers(String userId);
}

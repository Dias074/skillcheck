import 'assessment_history.dart';

class CategoryPerformance {
  const CategoryPerformance(
    this.id,
    this.name,
    this.count,
    this.averagePercentage,
  );
  final String id;
  final String name;
  final int count;
  final double averagePercentage;
}

/// Each completed attempt has equal weight in the average, regardless of length.
class ProgressSummary {
  ProgressSummary(List<HistoryAttempt> history, {String? categoryId})
    : attempts = List.unmodifiable(
        history
            .where(
              (a) => categoryId == null || a.result.categoryId == categoryId,
            )
            .toList()
          ..sort((a, b) {
            final time = b.result.completedAt.compareTo(a.result.completedAt);
            return time != 0
                ? time
                : b.result.assessmentId.compareTo(a.result.assessmentId);
          }),
      );
  final List<HistoryAttempt> attempts;
  int get total => attempts.length;
  double get averagePercentage => total == 0
      ? 0
      : attempts.fold<double>(0, (sum, a) => sum + a.result.percentage) / total;
  List<HistoryAttempt> get recentChart =>
      attempts.take(10).toList().reversed.toList();
  List<CategoryPerformance> get categories {
    final groups = <String, List<HistoryAttempt>>{};
    for (final attempt in attempts) {
      groups.putIfAbsent(attempt.result.categoryId, () => []).add(attempt);
    }
    return [
      for (final entry in groups.entries)
        CategoryPerformance(
          entry.key,
          entry.value.first.categoryName,
          entry.value.length,
          entry.value.fold<double>(0, (sum, a) => sum + a.result.percentage) /
              entry.value.length,
        ),
    ]..sort((a, b) => a.name.compareTo(b.name));
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/supabase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../../progress/application/progress_providers.dart';
import '../data/supabase_topic_repository.dart';
import '../domain/topic_performance.dart';

final topicRepositoryProvider = Provider<TopicPerformanceRepository>(
  (ref) => SupabaseTopicRepository(ref.watch(supabaseClientProvider)),
);
final weakAreaPolicyProvider = Provider((ref) => const WeakAreaPolicy());
final userTopicAnswersProvider = FutureProvider.autoDispose
    .family<List<TopicAnswer>, String>((ref, userId) async {
      final current = ref.watch(authStateProvider.select((s) => s.user?.id));
      if (current != userId) return [];
      return ref.watch(topicRepositoryProvider).fetchAnswers(userId);
    });
final topicPerformanceProvider = Provider<AsyncValue<List<TopicPerformance>>>((
  ref,
) {
  final userId = ref.watch(authStateProvider.select((s) => s.user?.id));
  final categoryId = ref.watch(progressCategoryProvider);
  if (userId == null) return const AsyncData([]);
  final answers = ref.watch(userTopicAnswersProvider(userId));
  if (answers.isLoading) return const AsyncLoading();
  if (answers.hasError) return AsyncError(answers.error!, answers.stackTrace!);
  try {
    return AsyncData(
      const TopicPerformanceCalculator().calculate(
        answers.requireValue,
        userId: userId,
        categoryId: categoryId,
      ),
    );
  } catch (error, stack) {
    return AsyncError(error, stack);
  }
});

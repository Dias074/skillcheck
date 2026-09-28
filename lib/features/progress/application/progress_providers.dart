import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/supabase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../data/supabase_progress_repository.dart';
import '../domain/assessment_history.dart';

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => SupabaseProgressRepository(ref.watch(supabaseClientProvider)),
);
final userHistoryProvider = FutureProvider.autoDispose
    .family<List<HistoryAttempt>, String>((ref, userId) async {
      final current = ref.watch(authStateProvider.select((s) => s.user?.id));
      if (current != userId) return [];
      return ref.watch(progressRepositoryProvider).fetchHistory(userId);
    });
// Selecting a new account selects a NEW AsyncValue, without the old user's data.
final progressHistoryProvider = Provider<AsyncValue<List<HistoryAttempt>>>((
  ref,
) {
  final userId = ref.watch(authStateProvider.select((s) => s.user?.id));
  if (userId == null) return const AsyncData([]);
  return ref.watch(userHistoryProvider(userId));
});
final progressCategoryProvider = NotifierProvider<ProgressCategory, String?>(
  ProgressCategory.new,
);

class ProgressCategory extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(authStateProvider.select((s) => s.user?.id));
    return null;
  }

  void select(String? id) => state = id;
}

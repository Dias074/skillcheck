import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/supabase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../data/supabase_assessment_repository.dart';
import '../domain/assessment_repository.dart';
import '../domain/models/category.dart';

final assessmentRepositoryProvider = Provider<AssessmentRepository>(
  (ref) => SupabaseAssessmentRepository(ref.watch(supabaseClientProvider)),
);
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final userId = ref.watch(authStateProvider.select((state) => state.user?.id));
  if (userId == null) return [];
  return ref.watch(assessmentRepositoryProvider).fetchCategories();
});

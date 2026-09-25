import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/assessment_repository.dart';
import '../domain/models/category.dart';
import '../domain/models/question.dart';
import 'assessment_mapper.dart';

class SupabaseAssessmentRepository implements AssessmentRepository {
  const SupabaseAssessmentRepository(this.client);
  final SupabaseClient client;

  @override
  Future<List<Category>> fetchCategories() => guarded('categories', () async {
    final rows = await client
        .from('categories')
        .select()
        .order('sort_order')
        .order('id')
        .timeout(const Duration(seconds: 20));
    return rows.map(AssessmentMapper.category).toList(growable: false);
  });

  @override
  Future<List<Question>> fetchQuestions(String categoryId) =>
      guarded('questions', () async {
        final rows = await client
            .from('questions')
            .select('*, question_options!question_options_question_id_fkey(*)')
            .eq('category_id', categoryId)
            .order('sort_order')
            .order('id')
            .timeout(const Duration(seconds: 20));
        return rows.map(AssessmentMapper.question).toList(growable: false);
      });
}

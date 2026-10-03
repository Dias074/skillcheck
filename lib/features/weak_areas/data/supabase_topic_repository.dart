import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/topic_performance.dart';

class SupabaseTopicRepository implements TopicPerformanceRepository {
  const SupabaseTopicRepository(this.client);
  final SupabaseClient client;
  String _token(String userId) {
    final session = client.auth.currentSession;
    if (session == null || session.user.id != userId) {
      throw const AppFailure('Your account changed. Sign in and try again.');
    }
    return session.accessToken;
  }

  @override
  Future<List<TopicAnswer>> fetchAnswers(String userId) => guarded(
    'topic performance',
    () async {
      final token = _token(userId);
      final result = <TopicAnswer>[];
      const pageSize = 500;
      for (var offset = 0; ; offset += pageSize) {
        _token(userId);
        final rows = await client
            .from('assessment_attempt_answers')
            .select(
              'user_id,attempt_id,question_id,selected_option_id,is_correct,points_earned,'
              'question:questions!assessment_attempt_answers_question_id_fkey('
              'points,category_id,topic_id,category:categories!questions_category_id_fkey(name),'
              'topic:topics!questions_topic_id_category_id_fkey(name))',
            )
            .eq('user_id', userId)
            .order('attempt_id')
            .order('question_id')
            .range(offset, offset + pageSize - 1)
            .setHeader('Authorization', 'Bearer $token')
            .timeout(const Duration(seconds: 20));
        for (final row in rows) {
          if (row['user_id'] != userId) {
            throw const FormatException('Unexpected answer owner');
          }
          result.add(_map(row));
        }
        if (rows.length < pageSize) break;
      }
      _token(userId);
      return result;
    },
  );
  TopicAnswer _map(Map<String, dynamic> row) {
    final question = row['question'] as Map<String, dynamic>;
    return TopicAnswer(
      userId: row['user_id'] as String,
      attemptId: row['attempt_id'] as String,
      questionId: row['question_id'] as String,
      categoryId: question['category_id'] as String,
      categoryName:
          (question['category'] as Map<String, dynamic>)['name'] as String,
      topicId: question['topic_id'] as String,
      topicName: (question['topic'] as Map<String, dynamic>)['name'] as String,
      answered: row['selected_option_id'] != null,
      isCorrect: row['is_correct'] as bool,
      pointsEarned: row['points_earned'] as int,
      maxPoints: question['points'] as int,
    );
  }
}

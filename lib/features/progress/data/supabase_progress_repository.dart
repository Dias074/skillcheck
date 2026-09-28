import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/assessment_history.dart';
import 'progress_mapper.dart';

class SupabaseProgressRepository implements ProgressRepository {
  const SupabaseProgressRepository(this.client);
  final SupabaseClient client;

  String _token(String userId) {
    final session = client.auth.currentSession;
    if (session == null || session.user.id != userId) {
      throw const AppFailure('Your account changed. Sign in and try again.');
    }
    return session.accessToken;
  }

  @override
  Future<void> saveAttempt(
    String userId,
    CompletedAssessment submission,
  ) async {
    try {
      // Pin the submitting account's token. An account change during a request
      // must never attach user A's answers to user B's history.
      final token = _token(userId);
      final id = await client
          .rpc(
            'save_assessment_attempt',
            params: ProgressMapper.submission(submission),
          )
          .setHeader('Authorization', 'Bearer $token')
          .timeout(const Duration(seconds: 20));
      if (id != submission.result.assessmentId) {
        throw const AppFailure('The server did not confirm this attempt.');
      }
    } catch (error) {
      friendlyFailure(error, 'save assessment');
      throw const AppFailure(
        'Saving could not be confirmed. Your result is kept in this session. Retry saving before leaving.',
      );
    }
  }

  @override
  Future<List<HistoryAttempt>> fetchHistory(String userId) =>
      guarded('history', () async {
        final token = _token(userId);
        final result = <HistoryAttempt>[];
        // Do not silently truncate totals at the Supabase API's row limit.
        const pageSize = 500;
        for (var offset = 0; ; offset += pageSize) {
          _token(userId);
          final rows = await client
              .from('assessment_attempts')
              .select('*, categories(name)')
              .eq('user_id', userId)
              .order('completed_at', ascending: false)
              .order('id', ascending: false)
              .range(offset, offset + pageSize - 1)
              .setHeader('Authorization', 'Bearer $token')
              .timeout(const Duration(seconds: 20));
          result.addAll(rows.map(ProgressMapper.history));
          if (rows.length < pageSize) break;
        }
        _token(userId);
        // A new concurrent insert may move an item across page boundaries.
        return {for (final item in result) item.result.assessmentId: item}
            .values
            .toList();
      });
}

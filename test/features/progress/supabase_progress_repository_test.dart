import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:skillcheck/core/errors/app_failure.dart';
import 'package:skillcheck/features/assessments/domain/models/assessment.dart';
import 'package:skillcheck/features/assessments/domain/services/assessment_scorer.dart';
import 'package:skillcheck/features/progress/data/supabase_progress_repository.dart';
import 'package:skillcheck/features/progress/domain/assessment_history.dart';

import '../../fixtures/local_question_source.dart';

Future<void> setTestSession(SupabaseClient client, String user) =>
    client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'test-session-$user',
        'token_type': 'bearer',
        'user': {'id': user},
      }),
    );

CompletedAssessment submission() {
  final assessment = Assessment(
    id: 'test-attempt',
    categoryId: 'english',
    questions: const LocalQuestionSource().questions('english'),
    startedAt: DateTime.utc(2026),
  );
  return CompletedAssessment(
    assessment: assessment,
    answers: [],
    result: const AssessmentScorer().score(
      assessment: assessment,
      answers: [],
      completedAt: DateTime.utc(2026, 2),
    ),
  );
}

void main() {
  test(
    'RPC sends all skipped answers and pins the original account token',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.test',
        'sb_publishable_example',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode('test-attempt'),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      await setTestSession(client, 'user-a');
      final pending = SupabaseProgressRepository(client)
          .saveAttempt('user-a', submission());
      await setTestSession(client, 'user-b');
      await pending;
      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/rest/v1/rpc/save_assessment_attempt');
      expect(
        requests.single.headers['Authorization'],
        'Bearer test-session-user-a',
      );
      final body = jsonDecode(requests.single.body) as Map;
      expect(body['p_answers'], hasLength(3));
      expect(body['p_attempt']['skipped_count'], 3);
      expect(body['p_attempt']['user_id'], isNull);
    },
  );
  test(
    'repository loads every page with owner filter and deterministic ordering',
    () async {
      final offsets = <int>[];
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.test',
        'sb_publishable_example',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          final offset = int.parse(
            request.url.queryParameters['offset'] ?? '0',
          );
          offsets.add(offset);
          return http.Response(
            jsonEncode([
              for (var i = offset; i < (offset == 0 ? 500 : 501); i++)
                {
                  'id': 'attempt-$i',
                  'user_id': 'user-a',
                  'category_id': 'english',
                  'categories': {'name': 'English'},
                  'score': 0,
                  'max_score': 4,
                  'correct_count': 0,
                  'incorrect_count': 0,
                  'skipped_count': 3,
                  'completed_at': '2026-09-28T10:00:00Z',
                },
            ]),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      await setTestSession(client, 'user-a');
      final items = await SupabaseProgressRepository(client)
          .fetchHistory('user-a');
      expect(offsets, [0, 500]);
      expect(requests.first.url.queryParameters['user_id'], 'eq.user-a');
      expect(
        requests.first.url.queryParameters['order'],
        contains('completed_at.desc'),
      );
      expect(requests.first.url.queryParameters['order'], contains('id.desc'));
      expect(items, hasLength(501));
    },
  );
  test(
    'save failures are safe and wrong-account calls never reach the network',
    () async {
      int calls = 0;
      final client = SupabaseClient(
        'https://example.test',
        'sb_publishable_example',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          calls++;
          return http.Response(
            '{"message":"internal server detail"}',
            500,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      await setTestSession(client, 'user-a');
      final repo = SupabaseProgressRepository(client);
      await expectLater(
        repo.saveAttempt('user-a', submission()),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.message,
            'safe message',
            isNot(contains('internal server detail')),
          ),
        ),
      );
      expect(calls, 1);
      await expectLater(
        repo.saveAttempt('user-b', submission()),
        throwsA(isA<AppFailure>()),
      );
      await expectLater(
        repo.fetchHistory('user-b'),
        throwsA(isA<AppFailure>()),
      );
      expect(calls, 1);
    },
  );
}

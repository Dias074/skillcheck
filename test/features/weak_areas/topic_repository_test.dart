import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:skillcheck/core/errors/app_failure.dart';
import 'package:skillcheck/features/weak_areas/data/supabase_topic_repository.dart';

import '../progress/supabase_progress_repository_test.dart' show setTestSession;

Map<String, dynamic> row(int i, {String user = 'user-a'}) => {
  'user_id': user,
  'attempt_id': 'a$i',
  'question_id': 'q',
  'selected_option_id': i == 0 ? null : 'o',
  'is_correct': i != 0,
  'points_earned': i == 0 ? 0 : 2,
  'question': {
    'points': 2,
    'category_id': 'english',
    'topic_id': 'grammar',
    'category': {'name': 'English'},
    'topic': {'name': 'Grammar'},
  },
};

void main() {
  test(
    'fetches all pages, joins topic metadata, pins token and filters owner',
    () async {
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
          return http.Response(
            jsonEncode([
              for (var i = offset; i < (offset == 0 ? 500 : 501); i++) row(i),
            ]),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      await setTestSession(client, 'user-a');
      final answers = await SupabaseTopicRepository(client)
          .fetchAnswers('user-a');
      expect(answers.length, 501);
      expect(requests.length, 2);
      expect(requests.first.url.path, '/rest/v1/assessment_attempt_answers');
      expect(requests.first.url.queryParameters['user_id'], 'eq.user-a');
      expect(requests.last.url.queryParameters['offset'], '500');
      expect(
        requests.first.headers['Authorization'],
        'Bearer test-session-user-a',
      );
      expect(
        requests.first.url.queryParameters['select'],
        contains('questions_topic_id_category_id_fkey'),
      );
      expect(answers.first.answered, false);
      expect(answers.last.maxPoints, 2);
      expect(answers.last.pointsEarned, 2);
      expect(answers.last.topicName, 'Grammar');
    },
  );
  test('no session and wrong account never issue requests; foreign rows are rejected', () async {
    int calls = 0;
    final client = SupabaseClient(
      'https://example.test',
      'sb_publishable_example',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        calls++;
        return http.Response(
          jsonEncode([row(0, user: 'user-b')]),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    final repo = SupabaseTopicRepository(client);
    await expectLater(repo.fetchAnswers('user-a'), throwsA(isA<AppFailure>()));
    await setTestSession(client, 'user-a');
    await expectLater(repo.fetchAnswers('user-b'), throwsA(isA<AppFailure>()));
    expect(calls, 0);
    await expectLater(repo.fetchAnswers('user-a'), throwsA(isA<AppFailure>()));
    expect(calls, 1);
  });
  test(
    'account change while loading does not return the old user response',
    () async {
      late SupabaseClient client;
      client = SupabaseClient(
        'https://example.test',
        'sb_publishable_example',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          await setTestSession(client, 'user-b');
          return http.Response(
            jsonEncode([row(0)]),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      await setTestSession(client, 'user-a');
      await expectLater(
        SupabaseTopicRepository(client).fetchAnswers('user-a'),
        throwsA(isA<AppFailure>()),
      );
    },
  );
}

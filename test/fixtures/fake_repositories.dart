import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skillcheck/core/errors/app_failure.dart';
import 'package:skillcheck/features/auth/domain/auth_repository.dart';
import 'package:skillcheck/features/auth/application/auth_providers.dart';
import 'package:skillcheck/features/assessments/application/assessment_controller.dart';
import 'package:skillcheck/features/assessments/application/assessment_providers.dart';
import 'package:skillcheck/features/assessments/domain/assessment_repository.dart';
import 'package:skillcheck/features/assessments/domain/models/category.dart';
import 'package:skillcheck/features/assessments/domain/models/question.dart';
import 'package:skillcheck/features/profile/data/profile_repository.dart';

import 'local_question_source.dart';

import 'package:skillcheck/features/weak_areas/domain/topic_performance.dart';
import 'package:skillcheck/features/weak_areas/application/weak_areas_providers.dart';

import 'package:skillcheck/features/progress/application/progress_providers.dart';
import 'package:skillcheck/features/progress/domain/assessment_history.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({bool signedIn = true})
    : _current = signedIn
          ? const AuthSnapshot(
              user: AuthUser(id: 'user-a', email: 'learner@example.test'),
            )
          : const AuthSnapshot();
  AuthSnapshot _current;
  final _events = StreamController<AuthSnapshot>.broadcast(sync: true);
  Object? failure;
  bool confirmEmail = true;
  @override
  AuthSnapshot get current => _current;
  @override
  Stream<AuthSnapshot> get changes => _events.stream;
  void emit(AuthSnapshot value) {
    _current = value;
    _events.add(value);
  }

  void _check() {
    if (failure != null) throw failure!;
  }

  @override
  Future<void> signIn(String email, String password) async {
    _check();
    emit(
      AuthSnapshot(
        user: AuthUser(id: 'user-a', email: email),
      ),
    );
  }

  @override
  Future<bool> register(
    String email,
    String password,
    String displayName,
  ) async {
    _check();
    if (confirmEmail) return false;
    await signIn(email, password);
    return true;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    _check();
  }

  @override
  Future<void> updatePassword(String password) async {
    _check();
    emit(AuthSnapshot(user: current.user));
  }

  @override
  Future<void> signOut() async {
    _check();
    emit(const AuthSnapshot());
  }

  Future<void> dispose() => _events.close();
}

class FakeAssessmentRepository implements AssessmentRepository {
  const FakeAssessmentRepository();
  @override
  Future<List<Category>> fetchCategories() async =>
      LocalQuestionSource.categories;
  @override
  Future<List<Question>> fetchQuestions(String categoryId) async =>
      const LocalQuestionSource().questions(categoryId);
}

class FakeProfileRepository implements ProfileRepository {
  @override
  Future<UserProfile?> fetchProfile(String userId) async =>
      UserProfile(id: userId, displayName: 'Test Learner');
}

ProviderContainer testContainer({
  FakeAuthRepository? auth,
  AssessmentRepository? repository,
  DateTime Function()? clock,
  ProgressRepository? progress,
  TopicPerformanceRepository? topics,
}) {
  final fake = auth ?? FakeAuthRepository();
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(fake),
      assessmentRepositoryProvider.overrideWithValue(
        repository ?? const FakeAssessmentRepository(),
      ),
      profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      assessmentClockProvider.overrideWithValue(clock ?? DateTime.now),
      progressRepositoryProvider.overrideWithValue(
        progress ?? FakeProgressRepository(),
      ),
      topicRepositoryProvider.overrideWithValue(
        topics ?? FakeTopicRepository(),
      ),
    ],
  );
  // Repository disposal is normally owned by the production provider.
  container.read(authStateProvider);
  return container;
}

class FakeTopicRepository implements TopicPerformanceRepository {
  List<TopicAnswer> answers = [];
  bool fail = false;
  int calls = 0;
  final pending = <String, Completer<List<TopicAnswer>>>{};
  @override
  Future<List<TopicAnswer>> fetchAnswers(String userId) async {
    calls++;
    if (fail) throw const AppFailure('Test topic failure');
    return pending[userId]?.future ??
        answers.where((a) => a.userId == userId).toList();
  }
}

class FakeProgressRepository implements ProgressRepository {
  final saved = <String, Map<String, HistoryAttempt>>{};
  final submissions = <CompletedAssessment>[];
  int saveCalls = 0;
  int fetchCalls = 0;
  bool failSave = false;
  bool failAfterSave = false;
  bool failFetch = false;
  Completer<void>? pendingSave;
  final pendingFetch = <String, Completer<List<HistoryAttempt>>>{};
  @override
  Future<void> saveAttempt(
    String userId,
    CompletedAssessment submission,
  ) async {
    saveCalls++;
    submissions.add(submission);
    if (pendingSave != null) await pendingSave!.future;
    if (failSave) throw const AppFailure('Test save failure');
    saved
        .putIfAbsent(userId, () => {})
        .putIfAbsent(
          submission.result.assessmentId,
          () => HistoryAttempt(
            userId: userId,
            categoryName: LocalQuestionSource.categories
                .firstWhere((c) => c.id == submission.result.categoryId)
                .name,
            result: submission.result,
          ),
        );
    if (failAfterSave) throw const AppFailure('Test lost response');
  }

  @override
  Future<List<HistoryAttempt>> fetchHistory(String userId) async {
    fetchCalls++;
    if (failFetch) throw const AppFailure('Test history failure');
    return pendingFetch[userId]?.future ?? saved[userId]?.values.toList() ?? [];
  }
}

/// A deterministic repository with controllable failures/empty or pending loads.
class ControlledAssessmentRepository implements AssessmentRepository {
  List<Category> categories = LocalQuestionSource.categories;
  List<Question> questions = const LocalQuestionSource().questions('english');
  bool failCategories = false;
  bool failQuestions = false;
  Completer<List<Question>>? pending;
  @override
  Future<List<Category>> fetchCategories() async {
    if (failCategories) throw const AppFailure('Unable to load categories.');
    return categories;
  }

  @override
  Future<List<Question>> fetchQuestions(String categoryId) async {
    if (failQuestions) throw const AppFailure('Unable to load questions.');
    return pending?.future ?? questions;
  }
}

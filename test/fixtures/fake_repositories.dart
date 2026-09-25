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
    ],
  );
  // Repository disposal is normally owned by the production provider.
  container.read(authStateProvider);
  return container;
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

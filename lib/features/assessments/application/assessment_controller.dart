import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../auth/application/auth_providers.dart';
import '../../practice/domain/practice_question_selector.dart';
import '../../progress/application/progress_providers.dart';
import '../../progress/domain/assessment_history.dart';
import '../../weak_areas/application/weak_areas_providers.dart';
import '../../weak_areas/domain/topic_performance.dart';
import 'assessment_providers.dart';
import '../domain/models/assessment.dart';
import '../domain/models/assessment_result.dart';
import '../domain/services/assessment_scorer.dart';
import 'assessment_session.dart';

final assessmentScorerProvider = Provider((ref) => const AssessmentScorer());
final assessmentClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Kept alive across tab navigation; app restart clears the local attempt.
final assessmentControllerProvider =
    NotifierProvider<AssessmentController, AssessmentSession?>(
      AssessmentController.new,
    );

enum SessionMode { assessment, practice }

final practiceControllerProvider =
    NotifierProvider<AssessmentController, AssessmentSession?>(
      () => AssessmentController(mode: SessionMode.practice),
    );

class AssessmentController extends Notifier<AssessmentSession?> {
  AssessmentController({this.mode = SessionMode.assessment});
  final SessionMode mode;
  bool get isPractice => mode == SessionMode.practice;
  var _generation = 0;
  Future<AssessmentResult>? _pendingSave;

  @override
  AssessmentSession? build() {
    ref.watch(authStateProvider.select((auth) => auth.user?.id));
    _generation++;
    _pendingSave = null;
    return null;
  }

  Future<bool> start(String categoryId) async {
    if (!isPractice && state?.result != null && !state!.isSaved) {
      throw const AppFailure(
        'Save your latest result before starting another assessment.',
      );
    }
    final generation = ++_generation;
    final userId = ref.read(authStateProvider).user?.id;
    if (userId == null) {
      throw const AppFailure('Sign in before starting an assessment.');
    }
    final repository = ref.read(assessmentRepositoryProvider);
    final categories = await repository.fetchCategories();
    final matching = categories.where((category) => category.id == categoryId);
    if (matching.isEmpty) {
      throw const AppFailure('This assessment is no longer available.');
    }
    final category = matching.first;
    var questions = await repository.fetchQuestions(categoryId);
    if (!ref.mounted ||
        generation != _generation ||
        ref.read(authStateProvider).user?.id != userId) {
      return false;
    }
    if (isPractice) {
      final answers = await ref
          .read(topicRepositoryProvider)
          .fetchAnswers(userId);
      if (!ref.mounted ||
          generation != _generation ||
          ref.read(authStateProvider).user?.id != userId) {
        return false;
      }
      questions = const PracticeQuestionSelector().select(
        categoryId: categoryId,
        topics: const TopicPerformanceCalculator().calculate(
          answers,
          userId: userId,
          categoryId: categoryId,
        ),
        questions: questions,
        policy: ref.read(weakAreaPolicyProvider),
      );
    }
    if (!ref.mounted ||
        generation != _generation ||
        ref.read(authStateProvider).user?.id != userId) {
      return false;
    }
    if (questions.isEmpty) {
      throw const AppFailure(
        'No questions are available for this category yet.',
      );
    }
    final startedAt = ref.read(assessmentClockProvider)();
    final random = Random.secure();
    final uniqueId = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final assessment = Assessment(
      id: '${isPractice ? 'practice' : 'attempt'}-$uniqueId',
      categoryId: categoryId,
      questions: questions,
      startedAt: startedAt,
    );
    state = AssessmentSession(category: category, assessment: assessment);
    return true;
  }

  AssessmentSession get _editable {
    final session = state;
    if (session == null) throw StateError('Start an assessment first.');
    if (session.result != null) {
      throw StateError('Submitted answers cannot be changed.');
    }
    return session;
  }

  void selectAnswer(String optionId) {
    final session = _editable;
    if (!session.currentQuestion.options.any(
      (option) => option.id == optionId,
    )) {
      throw ArgumentError.value(
        optionId,
        'optionId',
        'Option is not in the current question.',
      );
    }
    state = session.copyWith(
      selections: {...session.selections, session.currentQuestion.id: optionId},
    );
  }

  void clearAnswer() {
    final session = _editable;
    state = session.copyWith(
      selections: {...session.selections}..remove(session.currentQuestion.id),
    );
  }

  void next() {
    final session = _editable;
    if (!session.isLast) {
      state = session.copyWith(questionIndex: session.questionIndex + 1);
    }
  }

  void previous() {
    final session = _editable;
    if (!session.isFirst) {
      state = session.copyWith(questionIndex: session.questionIndex - 1);
    }
  }

  Future<AssessmentResult> submit() {
    if (_pendingSave != null) return _pendingSave!;
    final session = state;
    if (session == null) throw StateError('Start an assessment first.');
    if (session.isSaved) return Future.value(session.result!);
    final userId = ref.read(authStateProvider).user?.id;
    if (userId == null) throw const AppFailure('Sign in before submitting.');
    final result =
        session.result ??
        ref
            .read(assessmentScorerProvider)
            .score(
              assessment: session.assessment,
              answers: session.answers,
              completedAt: ref.read(assessmentClockProvider)(),
            );
    if (isPractice) {
      state = session.copyWith(result: result);
      return Future.value(result);
    }
    state = session.copyWith(result: result, isSaving: true);
    final generation = _generation;
    return _pendingSave = _save(
      userId,
      generation,
      CompletedAssessment(
        assessment: session.assessment,
        result: result,
        answers: session.answers,
      ),
    );
  }

  Future<AssessmentResult> _save(
    String userId,
    int generation,
    CompletedAssessment submission,
  ) async {
    bool isCurrent() =>
        ref.mounted &&
        generation == _generation &&
        ref.read(authStateProvider).user?.id == userId;
    try {
      await ref
          .read(progressRepositoryProvider)
          .saveAttempt(userId, submission);
      if (isCurrent()) {
        state = state!.copyWith(isSaving: false, isSaved: true);
        ref.invalidate(userHistoryProvider(userId));
        ref.invalidate(userTopicAnswersProvider(userId));
      }
    } catch (error) {
      if (isCurrent()) {
        friendlyFailure(error, 'submit assessment');
        state = state!.copyWith(
          isSaving: false,
          saveError: 'Saving could not be confirmed. Your answers and result are kept here. Retry before refreshing or signing out.',
        );
      }
    } finally {
      if (isCurrent()) _pendingSave = null;
    }
    return submission.result;
  }
}

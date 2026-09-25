import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../auth/application/auth_providers.dart';
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

class AssessmentController extends Notifier<AssessmentSession?> {
  var _attemptNumber = 0;
  var _generation = 0;

  @override
  AssessmentSession? build() {
    ref.watch(authStateProvider.select((auth) => auth.user?.id));
    _generation++;
    return null;
  }

  Future<bool> start(String categoryId) async {
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
    final questions = await repository.fetchQuestions(categoryId);
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
    final assessment = Assessment(
      id: 'attempt-${startedAt.microsecondsSinceEpoch}-${++_attemptNumber}',
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

  AssessmentResult submit() {
    final existing = state?.result;
    if (existing != null) return existing;
    final session = _editable;
    final result = ref
        .read(assessmentScorerProvider)
        .score(
          assessment: session.assessment,
          answers: session.answers,
          completedAt: ref.read(assessmentClockProvider)(),
        );
    state = session.copyWith(result: result);
    return result;
  }
}

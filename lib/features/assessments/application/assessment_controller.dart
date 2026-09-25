import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/local_question_source.dart';
import '../domain/models/assessment.dart';
import '../domain/models/assessment_result.dart';
import '../domain/services/assessment_scorer.dart';
import 'assessment_session.dart';

final localQuestionSourceProvider = Provider(
  (ref) => const LocalQuestionSource(),
);
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

  @override
  AssessmentSession? build() => null;

  void start(String categoryId) {
    final source = ref.read(localQuestionSourceProvider);
    final category = source.category(categoryId);
    final startedAt = ref.read(assessmentClockProvider)();
    final assessment = Assessment(
      id: 'local-${startedAt.microsecondsSinceEpoch}-${++_attemptNumber}',
      categoryId: categoryId,
      questions: source.questions(categoryId),
      startedAt: startedAt,
    );
    state = AssessmentSession(category: category, assessment: assessment);
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

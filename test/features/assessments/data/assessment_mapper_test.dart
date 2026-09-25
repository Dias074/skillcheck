import 'package:flutter_test/flutter_test.dart';
import 'package:skillcheck/features/assessments/data/assessment_mapper.dart';
import 'package:skillcheck/features/assessments/domain/models/question.dart';

Map<String, dynamic> row() => {
  'id': 'q1',
  'category_id': 'english',
  'topic_id': 'grammar',
  'question_text': 'Choose the answer.',
  'question_type': 'multiple_choice',
  'correct_option_id': 'b',
  'explanation': 'Example explanation.',
  'difficulty': 'medium',
  'points': 3,
  'question_options': [
    {'id': 'b', 'option_text': 'Second', 'sort_order': 1},
    {'id': 'a', 'option_text': 'First', 'sort_order': 0},
  ],
};

void main() {
  test('maps category fields without SDK objects in domain', () {
    final category = AssessmentMapper.category({
      'id': 'english',
      'name': 'English',
      'description': 'Grammar',
    });
    expect(category.id, 'english');
    expect(category.description, 'Grammar');
    expect(
      () => AssessmentMapper.category({'id': '', 'name': 'English'}),
      throwsFormatException,
    );
  });
  test('maps types, weights, answer key and sorted options', () {
    final question = AssessmentMapper.question(row());
    expect(question.options.map((o) => o.id), ['a', 'b']);
    expect(question.points, 3);
    expect(question.correctOptionId, 'b');
    expect(question.type, QuestionType.multipleChoice);
    expect(question.difficulty, QuestionDifficulty.medium);
    expect(
      AssessmentMapper.question(row()..['question_type'] = 'true_false').type,
      QuestionType.trueFalse,
    );
  });
  test('invalid backend data fails instead of silently changing scoring', () {
    expect(
      () => AssessmentMapper.question(row()..['points'] = 0),
      throwsArgumentError,
    );
    expect(
      () => AssessmentMapper.question(row()..['question_type'] = 'essay'),
      throwsFormatException,
    );
    expect(
      () => AssessmentMapper.question(row()..['correct_option_id'] = 'foreign'),
      throwsArgumentError,
    );
    expect(
      () => AssessmentMapper.question(row()..['question_options'] = []),
      throwsArgumentError,
    );
    expect(
      () => AssessmentMapper.question(row()..['difficulty'] = 'unknown'),
      throwsArgumentError,
    );
  });
}

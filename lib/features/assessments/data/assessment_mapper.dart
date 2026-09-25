import '../domain/models/category.dart';
import '../domain/models/question.dart';
import '../domain/models/question_option.dart';

/// Explicit mapping keeps PostgreSQL column names out of domain models.
abstract final class AssessmentMapper {
  static String _text(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Invalid $key');
    }
    return value;
  }

  static Category category(Map<String, dynamic> row) => Category(
    id: _text(row, 'id'),
    name: _text(row, 'name'),
    description: row['description'] as String? ?? '',
  );

  static Question question(Map<String, dynamic> row) {
    final options =
        (row['question_options'] as List)
            .map((value) => Map<String, dynamic>.from(value as Map))
            .toList()
          ..sort(
            (a, b) =>
                (a['sort_order'] as int).compareTo(b['sort_order'] as int),
          );
    return Question(
      id: _text(row, 'id'),
      categoryId: _text(row, 'category_id'),
      topicId: _text(row, 'topic_id'),
      questionText: _text(row, 'question_text'),
      type: switch (_text(row, 'question_type')) {
        'multiple_choice' => QuestionType.multipleChoice,
        'true_false' => QuestionType.trueFalse,
        _ => throw const FormatException('Unsupported question type'),
      },
      difficulty: QuestionDifficulty.values.byName(_text(row, 'difficulty')),
      options: options
          .map(
            (option) => QuestionOption(
              id: _text(option, 'id'),
              text: _text(option, 'option_text'),
            ),
          )
          .toList(),
      correctOptionId: _text(row, 'correct_option_id'),
      explanation: _text(row, 'explanation'),
      points: row['points'] as int,
    );
  }
}

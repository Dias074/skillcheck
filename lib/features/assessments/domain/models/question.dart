import 'question_option.dart';

enum QuestionType { multipleChoice, trueFalse }

enum QuestionDifficulty { easy, medium, hard }

/// Both supported types have exactly one correct option.
/// Local answer keys support the prototype; this is not a secure exam boundary.
class Question {
  Question({
    required this.id,
    required this.categoryId,
    required this.topicId,
    required this.questionText,
    required this.type,
    required this.difficulty,
    required List<QuestionOption> options,
    required this.correctOptionId,
    required this.explanation,
    this.points = 1,
  }) : options = List.unmodifiable(options) {
    if ([
      id,
      categoryId,
      topicId,
      questionText,
      explanation,
    ].any((value) => value.trim().isEmpty)) {
      throw ArgumentError(
        'Question identifiers, text and explanation must not be blank.',
      );
    }
    if (points <= 0) {
      throw ArgumentError.value(points, 'points', 'Must be positive.');
    }
    if (options.length < 2 ||
        (type == QuestionType.trueFalse && options.length != 2)) {
      throw ArgumentError(
        'Multiple choice needs at least two options; true/false needs exactly two.',
      );
    }
    final optionIds = <String>{};
    for (final option in options) {
      if (option.id.trim().isEmpty ||
          option.text.trim().isEmpty ||
          !optionIds.add(option.id)) {
        throw ArgumentError(
          'Options must have nonblank text and unique, nonblank IDs.',
        );
      }
    }
    if (!optionIds.contains(correctOptionId)) {
      throw ArgumentError.value(
        correctOptionId,
        'correctOptionId',
        'Must identify an option in this question.',
      );
    }
  }

  final String id;
  final String categoryId;
  final String topicId;
  final String questionText;
  final QuestionType type;
  final QuestionDifficulty difficulty;
  final List<QuestionOption> options;
  final String correctOptionId;
  final String explanation;
  final int points;
}

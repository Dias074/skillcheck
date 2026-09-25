import '../../domain/models/category.dart';
import '../../domain/models/question.dart';
import '../../domain/models/question_option.dart';

/// Demo-only content. Never presented as production history or a validated exam.
class LocalQuestionSource {
  const LocalQuestionSource();

  static const categories = [
    Category(
      id: 'english',
      name: 'English',
      description: 'Grammar and vocabulary',
    ),
    Category(
      id: 'kazakh',
      name: 'Kazakh',
      description: 'Everyday words and grammar',
    ),
    Category(
      id: 'russian',
      name: 'Russian',
      description: 'Everyday words and grammar',
    ),
    Category(
      id: 'logic',
      name: 'Logic & Reasoning',
      description: 'Patterns and reasoning',
    ),
    Category(
      id: 'programming',
      name: 'Programming',
      description: 'Dart fundamentals',
    ),
  ];

  Category category(String id) => categories.firstWhere(
    (category) => category.id == id,
    orElse: () =>
        throw ArgumentError.value(id, 'categoryId', 'Unknown sample category.'),
  );

  List<Question> questions(String categoryId) {
    category(categoryId);
    return List.unmodifiable(
      _questions.where((question) => question.categoryId == categoryId),
    );
  }

  static Question _choice(
    String category,
    String id,
    String topic,
    String text,
    List<String> choices,
    int correct,
    String explanation, {
    bool binary = false,
    int points = 1,
  }) => Question(
    id: id,
    categoryId: category,
    topicId: '${category}_$topic',
    questionText: text,
    type: binary ? QuestionType.trueFalse : QuestionType.multipleChoice,
    difficulty: QuestionDifficulty.easy,
    options: [
      for (var i = 0; i < choices.length; i++)
        QuestionOption(id: '${id}_$i', text: choices[i]),
    ],
    correctOptionId: '${id}_$correct',
    explanation: explanation,
    points: points,
  );

  static final _questions = [
    _choice(
      'english',
      'en_1',
      'grammar',
      'She ___ to university every day.',
      ['go', 'goes', 'going'],
      1,
      'With she, he or it, the Present Simple verb normally takes -s or -es.',
    ),
    _choice(
      'english',
      'en_2',
      'vocabulary',
      '“Quick” and “fast” can have similar meanings.',
      ['True', 'False'],
      0,
      'Both words can describe something moving or happening at high speed.',
      binary: true,
    ),
    _choice(
      'english',
      'en_3',
      'grammar',
      'Choose the correct sentence.',
      ['They is ready.', 'They am ready.', 'They are ready.'],
      2,
      'The pronoun they takes are in the present tense.',
      points: 2,
    ),
    _choice(
      'kazakh',
      'kk_1',
      'vocabulary',
      '«Кітап» сөзінің ағылшынша аудармасы қандай?',
      ['Book', 'Window', 'Water'],
      0,
      '«Кітап» ағылшын тілінде book деп аударылады.',
    ),
    _choice(
      'kazakh',
      'kk_2',
      'grammar',
      '«Балалар» сөзі көпше түрде берілген.',
      ['Дұрыс', 'Бұрыс'],
      0,
      'Бала сөзіне -лар көптік жалғауы жалғанған.',
      binary: true,
    ),
    _choice(
      'kazakh',
      'kk_3',
      'vocabulary',
      '«Үлкен» сөзінің антонимін таңдаңыз.',
      ['Ұзын', 'Кіші', 'Жақсы'],
      1,
      'Үлкен және кіші — қарама-қарсы мағыналы сөздер.',
      points: 2,
    ),
    _choice(
      'russian',
      'ru_1',
      'grammar',
      'Выберите форму множественного числа слова «книга».',
      ['Книгой', 'Книги', 'Книгу'],
      1,
      'Книги — форма именительного падежа множественного числа.',
    ),
    _choice(
      'russian',
      'ru_2',
      'vocabulary',
      'Слова «горячий» и «холодный» — синонимы.',
      ['Верно', 'Неверно'],
      1,
      'Эти слова имеют противоположные значения: это антонимы.',
      binary: true,
    ),
    _choice(
      'russian',
      'ru_3',
      'grammar',
      'Вставьте слово: «Она ___ письмо вчера».',
      ['написала', 'написал', 'написали'],
      0,
      'Местоимение «она» требует формы прошедшего времени женского рода.',
      points: 2,
    ),
    _choice(
      'logic',
      'logic_1',
      'patterns',
      'What comes next: 2, 4, 8, 16, ...?',
      ['18', '24', '32'],
      2,
      'Each number is twice the previous number.',
    ),
    _choice(
      'logic',
      'logic_2',
      'deduction',
      'All cats are mammals. Therefore, all mammals are cats.',
      ['True', 'False'],
      1,
      'The first statement does not imply its reverse; other mammals can exist.',
      binary: true,
    ),
    _choice(
      'logic',
      'logic_3',
      'numerical',
      'A box has 3 rows of 4 counters. How many counters are there?',
      ['7', '12', '16'],
      1,
      'Three equal rows of four contain 3 × 4 = 12 counters.',
      points: 2,
    ),
    _choice(
      'programming',
      'dart_1',
      'variables',
      'In Dart, what does final mean for a variable?',
      [
        'It can be assigned only once.',
        'It must contain an integer.',
        'It is always globally visible.',
      ],
      0,
      'A final variable can be assigned once. This does not automatically make a referenced collection immutable.',
    ),
    _choice(
      'programming',
      'dart_2',
      'null_safety',
      'A Dart variable declared as String? can contain null.',
      ['True', 'False'],
      0,
      'The question mark marks a nullable type.',
      binary: true,
    ),
    _choice(
      'programming',
      'dart_3',
      'operators',
      'What does this Dart expression evaluate to?\n\n7 ~/ 2',
      ['3.5', '3', '4'],
      1,
      'The ~/ operator performs truncating division, so 7 ~/ 2 is 3.',
      points: 2,
    ),
  ];
}

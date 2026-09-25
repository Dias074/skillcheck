import 'dart:io';

import '../test/fixtures/local_question_source.dart';

String sql(String value) => "'${value.replaceAll("'", "''")}'";

void main() {
  const source = LocalQuestionSource();
  final output = StringBuffer(
    '-- Representative educational content, not user history.\n-- Generated with dart run tool/generate_sample_seed.dart\nbegin;\n',
  );
  final topics = <String>{};
  for (var c = 0; c < LocalQuestionSource.categories.length; c++) {
    final category = LocalQuestionSource.categories[c];
    output.writeln(
      'insert into public.categories(id, name, description, sort_order) values (${sql(category.id)}, ${sql(category.name)}, ${sql(category.description)}, $c) on conflict (id) do nothing;',
    );
    final questions = source.questions(category.id);
    for (var q = 0; q < questions.length; q++) {
      final question = questions[q];
      if (topics.add(question.topicId)) {
        final name = question.topicId
            .substring(category.id.length + 1)
            .replaceAll('_', ' ');
        output.writeln(
          'insert into public.topics(id, category_id, name) values (${sql(question.topicId)}, ${sql(category.id)}, ${sql(name)}) on conflict (id) do nothing;',
        );
      }
      final type = question.type.name == 'trueFalse'
          ? 'true_false'
          : 'multiple_choice';
      output.writeln(
        'insert into public.questions(id, category_id, topic_id, question_text, question_type, correct_option_id, explanation, difficulty, points, sort_order) values (${sql(question.id)}, ${sql(category.id)}, ${sql(question.topicId)}, ${sql(question.questionText)}, ${sql(type)}, ${sql(question.correctOptionId)}, ${sql(question.explanation)}, ${sql(question.difficulty.name)}, ${question.points}, $q) on conflict (id) do nothing;',
      );
      for (var o = 0; o < question.options.length; o++) {
        final option = question.options[o];
        output.writeln(
          'insert into public.question_options(id, question_id, option_text, sort_order) values (${sql(option.id)}, ${sql(question.id)}, ${sql(option.text)}, $o) on conflict (id) do nothing;',
        );
      }
    }
  }
  output.writeln('commit;');
  File('supabase/migrations/20260925000200_sample_content.sql')
      .writeAsStringSync(output.toString());
}

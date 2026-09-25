import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/page_content.dart';
import '../application/assessment_controller.dart';
import '../data/local/local_question_source.dart';

class AssessmentsScreen extends ConsumerWidget {
  const AssessmentsScreen({super.key});

  Future<void> _start(
    BuildContext context,
    WidgetRef ref,
    String categoryId,
  ) async {
    final session = ref.read(assessmentControllerProvider);
    if (session != null && session.result == null) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace current attempt?'),
          content: const Text(
            'Starting another assessment discards your current answers. You can cancel and resume instead.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Start new attempt'),
            ),
          ],
        ),
      );
      if (replace != true || !context.mounted) return;
    }
    ref.read(assessmentControllerProvider.notifier).start(categoryId);
    context.go('/assessments/session');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(assessmentControllerProvider);
    final source = ref.watch(localQuestionSourceProvider);
    return PageContent(
      title: 'Assessments',
      description: 'Local sample assessments',
      children: [
        const Text(
          'Three questions per subject. Educational demos, not certified language levels or IQ tests. One attempt is kept in memory; restarting the app clears it.',
        ),
        const SizedBox(height: 16),
        if (session != null) ...[
          OutlinedButton(
            onPressed: () => context.go(
              session.result == null
                  ? '/assessments/session'
                  : '/assessments/result',
            ),
            child: Text(
              session.result == null
                  ? 'Resume ${session.category.name}'
                  : 'View latest result',
            ),
          ),
          const SizedBox(height: 16),
        ],
        for (final category in LocalQuestionSource.categories) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${category.description} • ${source.questions(category.id).length} questions',
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => _start(context, ref, category.id),
                    child: Text('Start ${category.name}'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/page_content.dart';
import '../application/assessment_controller.dart';
import 'widgets/session_unavailable.dart';

class QuestionScreen extends ConsumerWidget {
  const QuestionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(assessmentControllerProvider);
    if (session == null) return const SessionUnavailable();
    if (session.result != null) {
      return PageContent(
        title: 'Assessment submitted',
        description: 'Your answers are locked.',
        children: [
          FilledButton(
            onPressed: () => context.go('/assessments/result'),
            child: const Text('View result'),
          ),
        ],
      );
    }
    final controller = ref.read(assessmentControllerProvider.notifier);
    final question = session.currentQuestion;
    final selected = session.selections[question.id];
    return PageContent(
      key: ValueKey(question.id),
      title: session.category.name,
      description: 'No answers are revealed until submission.',
      children: [
        Text(
          'Question ${session.questionIndex + 1} of ${session.assessment.questions.length}',
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: session.progress,
          semanticsLabel: 'Question progress',
        ),
        const SizedBox(height: 8),
        Text(
          '${session.selections.length} answered • ${session.skippedCount} unanswered',
        ),
        const SizedBox(height: 24),
        Text(
          question.questionText,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        for (final option in question.options) ...[
          Semantics(
            selected: selected == option.id,
            child: OutlinedButton.icon(
              key: ValueKey(option.id),
              onPressed: () => controller.selectAnswer(option.id),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.all(16),
                backgroundColor: selected == option.id
                    ? Theme.of(context).colorScheme.secondaryContainer
                    : null,
              ),
              icon: Icon(
                selected == option.id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              label: Text(option.text),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: selected == null ? null : controller.clearAnswer,
            child: const Text('Clear answer'),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton(
              onPressed: session.isFirst ? null : controller.previous,
              child: const Text('Previous'),
            ),
            if (!session.isLast)
              FilledButton(
                onPressed: controller.next,
                child: const Text('Next'),
              )
            else
              FilledButton(
                onPressed: () {
                  controller.submit();
                  context.go('/assessments/result');
                },
                child: const Text('Submit assessment'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'You can leave questions unanswered. Skipped questions earn 0 points. Submission locks your answers.',
        ),
      ],
    );
  }
}

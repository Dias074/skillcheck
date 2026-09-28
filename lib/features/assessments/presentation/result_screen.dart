import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/page_content.dart';
import '../application/assessment_controller.dart';
import 'widgets/session_unavailable.dart';
import 'widgets/assessment_save_status.dart';

class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(assessmentControllerProvider);
    final result = session?.result;
    if (session == null || result == null) return const SessionUnavailable();
    return PageContent(
      title: '${session.category.name} result',
      description: 'Your completed assessment',
      children: [
        const AssessmentSaveStatus(),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${result.percentage.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 8),
                Text('Score: ${result.score} / ${result.maxScore} points'),
                const SizedBox(height: 16),
                Text('Correct: ${result.correctAnswers}'),
                Text('Incorrect: ${result.incorrectAnswers}'),
                Text('Skipped: ${result.unansweredQuestions}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Percentage is based on question points. This short sample does not certify a language level or measure IQ.',
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton(
              onPressed: () => context.go('/assessments/review'),
              child: const Text('Review answers'),
            ),
            OutlinedButton(
              onPressed: () => context.go('/assessments'),
              child: const Text('Back to assessments'),
            ),
            TextButton(
              onPressed: () => context.go('/progress'),
              child: const Text('View progress'),
            ),
            TextButton(
              onPressed: () => context.go('/home'),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ],
    );
  }
}

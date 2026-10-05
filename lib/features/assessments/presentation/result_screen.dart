import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/page_content.dart';
import '../application/assessment_controller.dart';
import 'widgets/session_unavailable.dart';
import 'widgets/assessment_save_status.dart';

class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key, this.practice = false});
  final bool practice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = practice
        ? practiceControllerProvider
        : assessmentControllerProvider;
    final route = practice ? '/progress/practice' : '/assessments';
    final session = ref.watch(provider);
    final result = session?.result;
    if (session == null || result == null) {
      return SessionUnavailable(practice: practice);
    }
    return PageContent(
      title: practice
          ? '${session.category.name} practice result'
          : '${session.category.name} result',
      description: practice
          ? 'Practice result • Not saved. History and Weak Areas are unchanged.'
          : 'Your completed assessment',
      children: [
        if (!practice) const AssessmentSaveStatus(),
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
              onPressed: () => context.go('$route/review'),
              child: const Text('Review answers'),
            ),
            OutlinedButton(
              onPressed: () =>
                  context.go(practice ? '/progress' : '/assessments'),
              child: Text(
                practice ? 'Back to Progress' : 'Back to assessments',
              ),
            ),
            if (!practice)
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

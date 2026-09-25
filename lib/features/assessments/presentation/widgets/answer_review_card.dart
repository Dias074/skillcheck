import 'package:flutter/material.dart';

import '../../application/assessment_session.dart';

class AnswerReviewCard extends StatelessWidget {
  const AnswerReviewCard({
    required this.review,
    required this.number,
    super.key,
  });
  final AnswerReview review;
  final int number;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, icon) = switch (review.status) {
      ReviewStatus.correct => ('Correct', Icons.check_circle_outline),
      ReviewStatus.incorrect => ('Incorrect', Icons.cancel_outlined),
      ReviewStatus.skipped => ('Skipped', Icons.remove_circle_outline),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: review.status == ReviewStatus.incorrect
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(label, style: theme.textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '$number. ${review.question.questionText}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text('Your answer: ${review.selectedText}'),
            const SizedBox(height: 8),
            Text('Correct answer: ${review.correctText}'),
            const SizedBox(height: 12),
            Text('Explanation: ${review.question.explanation}'),
          ],
        ),
      ),
    );
  }
}

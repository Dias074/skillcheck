import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/page_content.dart';
import '../application/assessment_controller.dart';
import 'widgets/answer_review_card.dart';
import 'widgets/session_unavailable.dart';

class AnswerReviewScreen extends ConsumerWidget {
  const AnswerReviewScreen({super.key, this.practice = false});
  final bool practice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = practice
        ? practiceControllerProvider
        : assessmentControllerProvider;
    final route = practice ? '/progress/practice' : '/assessments';
    final session = ref.watch(provider);
    if (session == null || session.result == null) {
      return SessionUnavailable(practice: practice);
    }
    final reviews = session.review;
    return PageContent(
      title: 'Answer review',
      description: practice
          ? '${session.category.name} • Practice'
          : session.category.name,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => context.go('$route/result'),
            child: const Text('Back to result'),
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < reviews.length; i++) ...[
          AnswerReviewCard(review: reviews[i], number: i + 1),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

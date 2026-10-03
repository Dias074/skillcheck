import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../application/weak_areas_providers.dart';
import '../domain/topic_performance.dart';

class WeakAreasSection extends ConsumerWidget {
  const WeakAreasSection({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(topicPerformanceProvider);
    final policy = ref.watch(weakAreaPolicyProvider);
    final userId = ref.watch(authStateProvider.select((s) => s.user?.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Weak Areas', style: Theme.of(context).textTheme.titleLarge),
        Text(
          'Below ${policy.threshold.toStringAsFixed(0)}% after at least ${policy.minimumAnswers} answers across ${policy.minimumAttempts} attempts and ${policy.minimumQuestions} different questions. Skips are excluded from the percentage.',
        ),
        const Text(
          'Based on the questions you have practised, not a certified skill level.',
        ),
        const SizedBox(height: 12),
        if (topics.isLoading)
          const LinearProgressIndicator()
        else if (topics.hasError) ...[
          const Text(
            'Unable to load topic performance. Check your connection and retry.',
          ),
          TextButton(
            onPressed: userId == null
                ? null
                : () => ref.invalidate(userTopicAnswersProvider(userId)),
            child: const Text('Retry topic analysis'),
          ),
        ] else ...[
          if (topics.requireValue.isEmpty)
            const Text(
              'No topic data yet. Complete an assessment in this category.',
            )
          else if (topics.requireValue.every(
            (t) => policy.classify(t) == TopicStatus.insufficientData,
          ))
            const Text('Not enough evidence yet to identify weak topics.')
          else if (!topics.requireValue.any(
            (t) => policy.classify(t) == TopicStatus.weak,
          ))
            const Text('No weak topics among those with enough evidence.'),
          for (final topic in topics.requireValue)
            _TopicCard(topic: topic, policy: policy),
        ],
      ],
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.topic, required this.policy});
  final TopicPerformance topic;
  final WeakAreaPolicy policy;
  @override
  Widget build(BuildContext context) {
    final status = policy.classify(topic);
    final percentage = topic.percentage;
    final reason = switch (status) {
      TopicStatus.weak =>
        'Weak topic: ${percentage!.toStringAsFixed(1)}% is below ${policy.threshold.toStringAsFixed(0)}%, with enough answered questions and attempts.',
      TopicStatus.satisfactory =>
        'At or above the ${policy.threshold.toStringAsFixed(0)}% threshold with enough evidence.',
      TopicStatus.insufficientData =>
        'Insufficient data: ${topic.answered}/${policy.minimumAnswers} answers, ${topic.answeredAttemptCount}/${policy.minimumAttempts} attempts with answers, ${topic.distinctQuestions}/${policy.minimumQuestions} different questions. All minimums must be met.',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${topic.categoryName} • ${topic.topicName}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              percentage == null
                  ? 'Performance: —'
                  : 'Performance: ${percentage.toStringAsFixed(1)}%',
            ),
            Text(reason),
            const SizedBox(height: 8),
            Text(
              'Answered: ${topic.answered} • Correct: ${topic.correct} • Incorrect: ${topic.incorrect} • Skipped: ${topic.skipped}',
            ),
            Text(
              'Points: ${topic.pointsEarned} / ${topic.availablePoints} (answered questions)',
            ),
            Text('Attempts containing this topic: ${topic.attemptCount}'),
          ],
        ),
      ),
    );
  }
}

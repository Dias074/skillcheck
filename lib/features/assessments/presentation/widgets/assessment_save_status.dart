import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/assessment_controller.dart';

class AssessmentSaveStatus extends ConsumerWidget {
  const AssessmentSaveStatus({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(assessmentControllerProvider);
    if (session == null || session.result == null) {
      return const SizedBox.shrink();
    }
    if (session.isSaved) return const Text('Saved to your history');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (session.isSaving) ...[
          const LinearProgressIndicator(),
          const Text('Saving result… Keep this session open.'),
        ] else ...[
          Text(
            session.saveError ?? 'This result has not been saved yet.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          FilledButton(
            onPressed: () =>
                ref.read(assessmentControllerProvider.notifier).submit(),
            child: const Text('Retry saving'),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

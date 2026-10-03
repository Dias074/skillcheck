import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/widgets/page_content.dart';
import '../../auth/application/auth_providers.dart';
import '../../assessments/application/assessment_providers.dart';
import '../application/progress_providers.dart';
import '../domain/assessment_history.dart';
import '../domain/progress_summary.dart';
import 'history_list.dart';
import 'progress_chart.dart';
import '../../weak_areas/presentation/weak_areas_section.dart';
import '../../weak_areas/application/weak_areas_providers.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(progressHistoryProvider);
    final userId = ref.watch(authStateProvider.select((s) => s.user?.id));
    return PageContent(
      title: 'Progress',
      description: 'Your saved assessment results.',
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: userId == null || history.isLoading
                ? null
                : () {
                    ref.invalidate(userHistoryProvider(userId));
                    ref.invalidate(userTopicAnswersProvider(userId));
                  },
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh history'),
          ),
        ),
        if (history.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (history.hasError) ...[
          Text(friendlyFailure(history.error!, 'progress UI').message),
          TextButton(
            onPressed: userId == null
                ? null
                : () => ref.invalidate(userHistoryProvider(userId)),
            child: const Text('Retry history'),
          ),
        ] else
          _ProgressContent(history: history.requireValue, userId: userId ?? ''),
      ],
    );
  }
}

class _ProgressContent extends ConsumerWidget {
  const _ProgressContent({required this.history, required this.userId});
  final List<HistoryAttempt> history;
  final String userId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryId = ref.watch(progressCategoryProvider);
    final available = ref.watch(categoriesProvider).asData?.value;
    final names = {
      for (final a in history) a.result.categoryId: a.categoryName,
      if (available != null)
        for (final c in available) c.id: c.name,
    };
    final summary = ProgressSummary(history, categoryId: categoryId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('filter:$userId:${categoryId ?? 'all'}'),
          initialValue: categoryId ?? '',
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Category',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(value: '', child: Text('All categories')),
            for (final entry in names.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: (id) => ref
              .read(progressCategoryProvider.notifier)
              .select(id == '' ? null : id),
        ),
        const SizedBox(height: 20),
        Text(
          categoryId == null ? 'All categories' : 'Selected category',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        Text(
          'Completed assessments: ${summary.total}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          summary.total == 0
              ? 'Average: —'
              : 'Average: ${summary.averagePercentage.toStringAsFixed(1)}%',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text(
          'Average of assessment percentages; each attempt has equal weight.',
        ),
        const SizedBox(height: 24),
        const WeakAreasSection(),
        const SizedBox(height: 24),
        if (summary.total == 0) ...[
          Text(
            history.isEmpty
                ? 'No completed assessments yet'
                : 'No history for this category',
          ),
          const Text(
            'Complete and save an assessment to see your progress here.',
          ),
          FilledButton(
            onPressed: () => context.go('/assessments'),
            child: const Text('Explore assessments'),
          ),
        ] else ...[
          ProgressChart(attempts: summary.recentChart),
          const SizedBox(height: 24),
          Text(
            'Category performance',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          for (final category in summary.categories)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${category.name} • ${category.count} completed • ${category.averagePercentage.toStringAsFixed(1)}% average',
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: category.averagePercentage / 100,
                    semanticsLabel: '${category.name} average',
                    semanticsValue:
                        '${category.averagePercentage.toStringAsFixed(1)}%',
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          HistoryList(
            key: ValueKey('history:$userId:$categoryId'),
            attempts: summary.attempts,
          ),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/widgets/page_content.dart';
import '../application/assessment_controller.dart';
import '../application/assessment_providers.dart';

class AssessmentsScreen extends ConsumerStatefulWidget {
  const AssessmentsScreen({super.key});
  @override
  ConsumerState<AssessmentsScreen> createState() => _AssessmentsScreenState();
}

class _AssessmentsScreenState extends ConsumerState<AssessmentsScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _start(String categoryId) async {
    if (_loading) return;
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
      if (replace != true || !mounted) return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final started = await ref
          .read(assessmentControllerProvider.notifier)
          .start(categoryId);
      if (mounted && started) context.go('/assessments/session');
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = friendlyFailure(error, 'start assessment').message;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(assessmentControllerProvider);
    final categories = ref.watch(categoriesProvider);
    return PageContent(
      title: 'Assessments',
      description: 'Choose an assessment',
      children: [
        const Text(
          'Educational questions, not certified language levels or IQ tests. Your current attempt stays in memory only.',
        ),
        const SizedBox(height: 16),
        if (session != null) ...[
          OutlinedButton(
            onPressed: _loading
                ? null
                : () => context.go(
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
        if (_loading) ...[
          const LinearProgressIndicator(),
          const Text('Loading questions…'),
          const SizedBox(height: 16),
        ],
        if (_error != null) ...[
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const Text('Select the category again to retry.'),
          const SizedBox(height: 16),
        ],
        categories.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(friendlyFailure(error, 'categories UI').message),
              TextButton(
                onPressed: () => ref.invalidate(categoriesProvider),
                child: const Text('Retry categories'),
              ),
            ],
          ),
          data: (items) => items.isEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('No assessment categories are available yet.'),
                    TextButton(
                      onPressed: () => ref.invalidate(categoriesProvider),
                      child: const Text('Refresh categories'),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final category in items) ...[
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
                              Text(category.description),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: _loading
                                    ? null
                                    : () => _start(category.id),
                                child: Text('Start ${category.name}'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

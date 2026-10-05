import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/widgets/page_content.dart';
import '../../assessments/application/assessment_controller.dart';
import '../domain/practice_question_selector.dart';

class PracticeStartScreen extends ConsumerStatefulWidget {
  const PracticeStartScreen({super.key, required this.categoryId});
  final String categoryId;
  @override
  ConsumerState<PracticeStartScreen> createState() =>
      _PracticeStartScreenState();
}

class _PracticeStartScreenState extends ConsumerState<PracticeStartScreen> {
  bool _loading = false;
  String? _message;

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final started = await ref
          .read(practiceControllerProvider.notifier)
          .start(widget.categoryId);
      if (mounted && started) context.go('/progress/practice/session');
    } on PracticeUnavailable catch (empty) {
      if (mounted) setState(() => _message = empty.message);
    } catch (error) {
      friendlyFailure(error, 'start practice');
      if (mounted) {
        setState(
          () => _message =
              'Unable to load practice. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(practiceControllerProvider);
    return PageContent(
      title: 'Weak topic practice',
      description: '2–5 questions from confirmed weak topics. Practice stays in memory and does not change assessment history or Weak Areas. Refreshing or signing out clears it.',
      children: [
        if (current != null) ...[
          Text(
            'Current practice: ${current.category.name}. Starting again replaces only this practice session.',
          ),
          TextButton(
            onPressed: _loading
                ? null
                : () => context.go(
                    current.result == null
                        ? '/progress/practice/session'
                        : '/progress/practice/result',
                  ),
            child: Text(
              current.result == null
                  ? 'Resume practice'
                  : 'View practice result',
            ),
          ),
        ],
        if (_loading) const LinearProgressIndicator(),
        if (_message != null) Text(_message!),
        FilledButton(
          onPressed: _loading ? null : _start,
          child: const Text('Start practice'),
        ),
        TextButton(
          onPressed: () => context.go('/progress'),
          child: const Text('Back to Progress'),
        ),
      ],
    );
  }
}

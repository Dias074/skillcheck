import 'package:flutter/material.dart';

import '../domain/assessment_history.dart';
import 'progress_chart.dart';

class HistoryList extends StatefulWidget {
  const HistoryList({required this.attempts, super.key});
  final List<HistoryAttempt> attempts;
  @override
  State<HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends State<HistoryList> {
  int _visible = 20;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Assessment history', style: Theme.of(context).textTheme.titleLarge),
      const Text('Newest first • dates shown in your local time'),
      for (final attempt in widget.attempts.take(_visible))
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attempt.categoryName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${attempt.result.score} / ${attempt.result.maxScore} points • ${attempt.result.percentage.toStringAsFixed(1)}%',
                ),
                Text(historyDate(context, attempt.result.completedAt)),
                Text(
                  'Correct: ${attempt.result.correctAnswers} • Incorrect: ${attempt.result.incorrectAnswers} • Skipped: ${attempt.result.unansweredQuestions}',
                ),
              ],
            ),
          ),
        ),
      if (_visible < widget.attempts.length)
        TextButton(
          onPressed: () => setState(() => _visible += 20),
          child: const Text('Show more history'),
        ),
    ],
  );
}

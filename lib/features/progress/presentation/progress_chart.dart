import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../domain/assessment_history.dart';

String historyDate(BuildContext context, DateTime value) {
  final date = value.toLocal();
  final labels = MaterialLocalizations.of(context);
  return '${labels.formatMediumDate(date)} ${labels.formatTimeOfDay(TimeOfDay.fromDateTime(date), alwaysUse24HourFormat: true)}';
}

class ProgressChart extends StatelessWidget {
  const ProgressChart({required this.attempts, super.key});

  /// At most ten attempts, ordered oldest first.
  final List<HistoryAttempt> attempts;
  @override
  Widget build(BuildContext context) {
    if (attempts.isEmpty) return const SizedBox.shrink();
    if (attempts.length == 1) {
      return Text(
        'First result: ${attempts.single.result.percentage.toStringAsFixed(1)}%. Complete another assessment to see a trend.',
      );
    }
    final color = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent progress', style: Theme.of(context).textTheme.titleLarge),
        const Text(
          'Up to 10 attempts, oldest → newest. Each point is one assessment.',
        ),
        const SizedBox(height: 16),
        Semantics(
          label:
              'Recent assessment percentages in completion order: ${attempts.map((a) => '${a.result.percentage.toStringAsFixed(1)} percent').join(', ')}',
          child: SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (attempts.length - 1).toDouble(),
                minY: 0,
                maxY: 100,
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: MediaQuery.textScalerOf(context).scale(48),
                      interval: 25,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}%',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
                  bottomTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < attempts.length; i++)
                        FlSpot(i.toDouble(), attempts[i].result.percentage),
                    ],
                    color: color,
                    barWidth: 3,
                    isCurved: false,
                    dotData: const FlDotData(show: true),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) =>
                        Theme.of(context).colorScheme.inverseSurface,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (spots) => spots.map((spot) {
                      final attempt = attempts[spot.spotIndex];
                      return LineTooltipItem(
                        '${attempt.categoryName}\n${historyDate(context, attempt.result.completedAt)}\n${spot.y.toStringAsFixed(1)}%',
                        TextStyle(
                          color: Theme.of(context).colorScheme.onInverseSurface,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              duration: Duration.zero,
            ),
          ),
        ),
      ],
    );
  }
}

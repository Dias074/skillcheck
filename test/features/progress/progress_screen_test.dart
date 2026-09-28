import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillcheck/app/app.dart';
import 'package:skillcheck/app/router/app_router.dart';
import 'package:skillcheck/features/assessments/application/assessment_controller.dart';
import 'package:skillcheck/features/progress/domain/assessment_history.dart';

import '../../fixtures/fake_repositories.dart';
import 'progress_test.dart' show historyAttempt;

Future<void> tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('history loading, error, retry, and empty states', (
    tester,
  ) async {
    final repo = FakeProgressRepository()
      ..pendingFetch['user-a'] = Completer<List<HistoryAttempt>>();
    final container = testContainer(progress: repo);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SkillCheckApp(),
      ),
    );
    container.read(appRouterProvider).go('/progress');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    repo.pendingFetch['user-a']!.completeError(
      Exception('Test network failure'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry history'), findsOneWidget);
    repo.pendingFetch.clear();
    await tap(tester, 'Retry history');
    expect(find.text('No completed assessments yet'), findsOneWidget);
    expect(find.text('Completed assessments: 0'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });
  testWidgets(
    'dashboard filters totals, chart and history on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = FakeProgressRepository();
      repo.saved['user-a'] = {
        'a': historyAttempt('a'),
        'b': historyAttempt('b', category: 'logic', score: 4, day: 2),
      };
      final container = testContainer(progress: repo);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SkillCheckApp(),
        ),
      );
      container.read(appRouterProvider).go('/progress');
      await tester.pumpAndSettle();
      expect(find.text('Completed assessments: 2'), findsOneWidget);
      expect(find.text('Average: 62.5%'), findsOneWidget);
      expect(find.byType(LineChart), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tap(tester, 'English');
      expect(find.text('Completed assessments: 1'), findsOneWidget);
      expect(find.text('Average: 25.0%'), findsOneWidget);
      expect(find.byType(LineChart), findsNothing);
      expect(find.textContaining('First result:'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tap(tester, 'Kazakh');
      expect(find.text('No history for this category'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('failed submit shows retry, preserves result and recovers', (
    tester,
  ) async {
    final repo = FakeProgressRepository()..failSave = true;
    final container = testContainer(progress: repo);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SkillCheckApp(),
      ),
    );
    final controller = container.read(assessmentControllerProvider.notifier);
    await controller.start('english');
    controller.next();
    controller.next();
    container.read(appRouterProvider).go('/assessments/session');
    await tester.pumpAndSettle();
    await tap(tester, 'Submit assessment');
    expect(find.text('Retry saving'), findsOneWidget);
    expect(repo.saveCalls, 1);
    expect(repo.saved, isEmpty);
    repo.failSave = false;
    await tap(tester, 'Retry saving');
    expect(find.text('Saved to your history'), findsOneWidget);
    await tap(tester, 'View result');
    expect(find.text('Skipped: 3'), findsOneWidget);
    await tap(tester, 'View progress');
    expect(find.text('Completed assessments: 1'), findsOneWidget);
    expect(repo.saved['user-a'], hasLength(1));
  });
}

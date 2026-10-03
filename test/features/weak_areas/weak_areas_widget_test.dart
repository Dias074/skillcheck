import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillcheck/app/app.dart';
import 'package:skillcheck/app/router/app_router.dart';
import 'package:skillcheck/features/weak_areas/domain/topic_performance.dart';

import '../../fixtures/fake_repositories.dart';
import 'weak_areas_test.dart' show answer;

void main() {
  testWidgets(
    'weak cards show weighted metrics and follow Progress category filter',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = FakeTopicRepository()
        ..answers = [
          for (var i = 0; i < 6; i++) answer(i),
          for (var i = 6; i < 12; i++)
            answer(i, category: 'kazakh', correct: true),
        ];
      final container = testContainer(topics: repo);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SkillCheckApp(),
        ),
      );
      container.read(appRouterProvider).go('/progress');
      await tester.pumpAndSettle();
      expect(find.text('Weak Areas'), findsOneWidget);
      expect(find.textContaining('Weak topic: 0.0%'), findsOneWidget);
      expect(find.text('Points: 0 / 6 (answered questions)'), findsOneWidget);
      expect(find.text('kazakh • grammar'), findsOneWidget);
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();
      expect(find.text('kazakh • grammar'), findsNothing);
      expect(find.textContaining('Weak topic:'), findsOneWidget);
      await tester.ensureVisible(
        find.text('Points: 0 / 6 (answered questions)'),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('loading and error can retry into an honest empty state', (
    tester,
  ) async {
    final repo = FakeTopicRepository()
      ..pending['user-a'] = Completer<List<TopicAnswer>>();
    final container = testContainer(topics: repo);
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
    expect(find.byType(LinearProgressIndicator), findsWidgets);
    repo.pending['user-a']!.completeError(Exception('Test failure'));
    await tester.pumpAndSettle();
    expect(find.text('Retry topic analysis'), findsOneWidget);
    repo.pending.clear();
    await tester.ensureVisible(find.text('Retry topic analysis'));
    await tester.tap(find.text('Retry topic analysis'));
    await tester.pumpAndSettle();
    expect(
      find.text('No topic data yet. Complete an assessment in this category.'),
      findsOneWidget,
    );
    expect(find.text('Retry topic analysis'), findsNothing);
  });
  testWidgets('one wrong answer is insufficient, not a weak topic', (
    tester,
  ) async {
    final repo = FakeTopicRepository()..answers = [answer(0)];
    final container = testContainer(topics: repo);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SkillCheckApp(),
      ),
    );
    container.read(appRouterProvider).go('/progress');
    await tester.pumpAndSettle();
    expect(
      find.text('Not enough evidence yet to identify weak topics.'),
      findsOneWidget,
    );
    expect(find.textContaining('Insufficient data: 1/5'), findsOneWidget);
    expect(find.textContaining('Weak topic:'), findsNothing);
  });
}

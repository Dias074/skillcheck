import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillcheck/app/app.dart';
import 'package:skillcheck/app/router/app_router.dart';
import 'package:skillcheck/core/errors/app_failure.dart';
import 'package:skillcheck/features/auth/domain/auth_repository.dart';
import 'package:skillcheck/features/auth/application/auth_providers.dart';
import 'package:skillcheck/features/assessments/application/assessment_controller.dart';

import '../../fixtures/fake_repositories.dart';

void main() {
  test(
    'restores repository session, confirms email, reports errors and logs out',
    () async {
      final auth = FakeAuthRepository(signedIn: false);
      final container = testContainer(auth: auth);
      addTearDown(container.dispose);
      addTearDown(auth.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await controller.register(
        'learner@example.test',
        'password123',
        'Learner',
      );
      expect(container.read(authStateProvider).user, isNull);
      expect(
        container.read(authControllerProvider).value,
        contains('confirm registration'),
      );
      auth.failure = const AppFailure('Email or password is incorrect.');
      await controller.login('learner@example.test', 'wrong');
      expect(container.read(authControllerProvider).hasError, isTrue);
      auth.failure = null;
      await controller.login(' learner@example.test ', 'password123');
      expect(
        container.read(authStateProvider).user!.email,
        'learner@example.test',
      );
      final fresh = testContainer(auth: auth);
      addTearDown(fresh.dispose);
      expect(fresh.read(authStateProvider).user!.id, 'user-a');
      await controller.logout();
      expect(container.read(authStateProvider).user, isNull);
    },
  );

  test(
    'password reset flow reports email status and clears recovery state',
    () async {
      final auth = FakeAuthRepository();
      final container = testContainer(auth: auth);
      addTearDown(container.dispose);
      addTearDown(auth.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await controller.forgotPassword('learner@example.test');
      expect(
        container.read(authControllerProvider).value,
        contains('If this email'),
      );
      auth.emit(AuthSnapshot(user: auth.current.user, passwordRecovery: true));
      await controller.resetPassword('newPassword123');
      expect(container.read(authStateProvider).passwordRecovery, isFalse);
    },
  );

  testWidgets(
    'protected routes redirect, form validates, login and logout update routing',
    (tester) async {
      final auth = FakeAuthRepository(signedIn: false);
      final container = testContainer(auth: auth);
      addTearDown(container.dispose);
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SkillCheckApp(),
        ),
      );
      container.read(appRouterProvider).go('/assessments/review');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'learner@example.test',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to SkillCheck'), findsOneWidget);
      container.read(appRouterProvider).go('/register');
      await tester.pumpAndSettle();
      expect(find.text('Welcome to SkillCheck'), findsOneWidget);
      await container
          .read(assessmentControllerProvider.notifier)
          .start('english');
      container.read(appRouterProvider).go('/profile');
      await tester.pumpAndSettle();
      expect(find.text('learner@example.test'), findsOneWidget);
      expect(find.text('Test Learner'), findsOneWidget);
      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
      expect(container.read(assessmentControllerProvider), isNull);
    },
  );

  testWidgets(
    'recovery event forces reset screen and completion returns home',
    (tester) async {
      final auth = FakeAuthRepository();
      final container = testContainer(auth: auth);
      addTearDown(container.dispose);
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SkillCheckApp(),
        ),
      );
      await tester.pumpAndSettle();
      auth.emit(AuthSnapshot(user: auth.current.user, passwordRecovery: true));
      await tester.pumpAndSettle();
      expect(find.text('Set new password'), findsNWidgets(2));
      container.read(appRouterProvider).go('/home');
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(FilledButton, 'Set new password'),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'newPassword123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm password'),
        'newPassword123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Set new password'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to SkillCheck'), findsOneWidget);
    },
  );
}

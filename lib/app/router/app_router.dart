import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/assessments/presentation/assessments_screen.dart';
import '../../features/assessments/presentation/question_screen.dart';
import '../../features/assessments/presentation/result_screen.dart';
import '../../features/assessments/presentation/answer_review_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/progress/presentation/progress_screen.dart';
import '../../shared/widgets/feature_placeholder.dart';
import 'main_navigation.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/presentation/auth_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (_, next) {
    refresh.value++;
  });
  ref.onDispose(refresh.dispose);
  final router = GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final path = state.uri.path;
      final publicRoute = [
        '/login',
        '/register',
        '/forgot-password',
      ].contains(path);
      if (auth.user == null) return publicRoute ? null : '/login';
      if (auth.passwordRecovery) {
        return path == '/reset-password' ? null : '/reset-password';
      }
      if (publicRoute || path == '/') return '/home';
      return null;
    },
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            const AuthScreen(key: ValueKey('login'), mode: AuthFormMode.login),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const AuthScreen(
          key: ValueKey('register'),
          mode: AuthFormMode.register,
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const AuthScreen(
          key: ValueKey('forgot'),
          mode: AuthFormMode.forgotPassword,
        ),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const AuthScreen(
          key: ValueKey('reset'),
          mode: AuthFormMode.resetPassword,
        ),
      ),
      GoRoute(path: '/', redirect: (context, state) => '/home'),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainNavigation(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/assessments',
                builder: (context, state) => const AssessmentsScreen(),
                routes: [
                  GoRoute(
                    path: 'session',
                    builder: (context, state) => const QuestionScreen(),
                  ),
                  GoRoute(
                    path: 'result',
                    builder: (context, state) => const ResultScreen(),
                  ),
                  GoRoute(
                    path: 'review',
                    builder: (context, state) => const AnswerReviewScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/progress',
                builder: (context, state) => const ProgressScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: SafeArea(
        child: Center(
          child: FeaturePlaceholder(
            icon: Icons.search_off,
            title: 'Page not found',
            description:
                'This page is not available. Return to the home screen.',
            action: FilledButton(
              onPressed: () => context.go('/home'),
              child: const Text('Back to Home'),
            ),
          ),
        ),
      ),
    ),
  );
  ref.onDispose(router.dispose);
  return router;
});

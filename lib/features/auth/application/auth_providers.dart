import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/supabase_providers.dart';
import '../data/supabase_auth_repository.dart';
import '../domain/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final repository = SupabaseAuthRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(appConfigProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final authStateProvider = NotifierProvider<AuthStateController, AuthSnapshot>(
  AuthStateController.new,
);

class AuthStateController extends Notifier<AuthSnapshot> {
  @override
  AuthSnapshot build() {
    final repository = ref.watch(authRepositoryProvider);
    final subscription = repository.changes.listen((value) {
      state = value;
    });
    ref.onDispose(subscription.cancel);
    return repository.current;
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AsyncValue<String?>>(AuthController.new);

class AuthController extends Notifier<AsyncValue<String?>> {
  @override
  AsyncValue<String?> build() => const AsyncData(null);

  Future<void> _run(Future<String?> Function() action) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(action);
    if (ref.mounted) state = result;
  }

  Future<void> login(String email, String password) => _run(() async {
    await ref.read(authRepositoryProvider).signIn(email.trim(), password);
    return null;
  });
  Future<void> register(String email, String password, String name) =>
      _run(() async {
        final signedIn = await ref
            .read(authRepositoryProvider)
            .register(email.trim(), password, name.trim());
        return signedIn
            ? null
            : 'Check your email to confirm registration, then sign in.';
      });
  Future<void> forgotPassword(String email) => _run(() async {
    await ref.read(authRepositoryProvider).sendPasswordReset(email.trim());
    return 'If this email has an account, a reset link will arrive shortly. Open it in this browser.';
  });
  Future<void> resetPassword(String password) => _run(() async {
    await ref.read(authRepositoryProvider).updatePassword(password);
    return 'Password updated.';
  });
  Future<void> logout() => _run(() async {
    await ref.read(authRepositoryProvider).signOut();
    return null;
  });
  void clearMessage() {
    if (!state.isLoading) state = const AsyncData(null);
  }
}

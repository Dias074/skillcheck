import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this.client, this.config) {
    _recovery = Uri.base.queryParameters['flow'] == 'recovery';
    _subscription = client.auth.onAuthStateChange.listen(
      (event) {
        if (event.event == AuthChangeEvent.passwordRecovery) _recovery = true;
        if (event.event == AuthChangeEvent.signedOut) _recovery = false;
        _events.add(current);
      },
      onError: (Object error, StackTrace stack) {
        friendlyFailure(error, 'auth state');
        _events.add(current);
      },
    );
  }
  final SupabaseClient client;
  final AppConfig config;
  final _events = StreamController<AuthSnapshot>.broadcast(sync: true);
  late final StreamSubscription<AuthState> _subscription;
  bool _recovery = false;

  @override
  AuthSnapshot get current {
    final user = client.auth.currentUser;
    return AuthSnapshot(
      user: user == null
          ? null
          : AuthUser(id: user.id, email: user.email ?? ''),
      passwordRecovery: user != null && _recovery,
    );
  }

  @override
  Stream<AuthSnapshot> get changes => _events.stream;

  @override
  Future<void> signIn(String email, String password) =>
      guarded('sign in', () async {
        await client.auth.signInWithPassword(email: email, password: password);
      });
  @override
  Future<bool> register(String email, String password, String displayName) =>
      guarded('register', () async {
        final response = await client.auth.signUp(
          email: email,
          password: password,
          data: {'display_name': displayName},
          emailRedirectTo: config.authRedirectUrl,
        );
        return response.session != null;
      });
  @override
  Future<void> sendPasswordReset(String email) => guarded(
    'password reset email',
    () => client.auth.resetPasswordForEmail(
      email,
      redirectTo: config.recoveryRedirectUrl,
    ),
  );
  @override
  Future<void> updatePassword(String password) =>
      guarded('update password', () async {
        await client.auth.updateUser(UserAttributes(password: password));
        _recovery = false;
        _events.add(current);
      });
  @override
  Future<void> signOut() =>
      guarded('sign out', () => client.auth.signOut(scope: SignOutScope.local));

  void dispose() {
    unawaited(_subscription.cancel());
    unawaited(_events.close());
  }
}

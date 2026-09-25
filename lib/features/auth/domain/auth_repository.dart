class AuthUser {
  const AuthUser({required this.id, required this.email});
  final String id;
  final String email;
}

class AuthSnapshot {
  const AuthSnapshot({this.user, this.passwordRecovery = false});
  final AuthUser? user;
  final bool passwordRecovery;
}

abstract interface class AuthRepository {
  AuthSnapshot get current;
  Stream<AuthSnapshot> get changes;
  Future<void> signIn(String email, String password);

  /// True when a session exists; false when email confirmation is required.
  Future<bool> register(String email, String password, String displayName);
  Future<void> sendPasswordReset(String email);
  Future<void> updatePassword(String password);
  Future<void> signOut();
}

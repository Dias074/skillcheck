import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

class AppFailure implements Exception {
  const AppFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Log type/code only: exception messages may contain emails, URLs or tokens.
AppFailure friendlyFailure(Object error, String operation) {
  if (error is AppFailure) return error;
  developer.log('Failed $operation (${error.runtimeType})', name: 'skillcheck');
  if (error is AuthException) {
    final message = switch (error.code) {
      'invalid_credentials' => 'Email or password is incorrect.',
      'email_not_confirmed' => 'Confirm your email before signing in.',
      'weak_password' => 'Choose a stronger password.',
      'over_request_rate_limit' || 'over_email_send_rate_limit' =>
        'Too many requests. Please wait and try again.',
      'same_password' =>
        'Choose a password different from your current password.',
      'session_not_found' || 'refresh_token_not_found' =>
        'Your session expired. Please sign in again.',
      _ => 'Unable to complete authentication. Check your connection and try again.',
    };
    return AppFailure(message);
  }
  return const AppFailure(
    'Unable to load data. Check your connection and try again.',
  );
}

Future<T> guarded<T>(String operation, Future<T> Function() action) async {
  try {
    return await action();
  } catch (error) {
    throw friendlyFailure(error, operation);
  }
}

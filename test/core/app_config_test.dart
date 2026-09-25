import 'package:flutter_test/flutter_test.dart';
import 'package:skillcheck/core/config/app_config.dart';

void main() {
  test('missing configuration and privileged key shapes are rejected', () {
    expect(const AppConfig.fromEnvironment().isValid, isFalse);
    expect(
      const AppConfig(
        url: 'https://test.supabase.co',
        publishableKey: 'sb_secret_example',
        authRedirectUrl: 'http://localhost:7357/',
      ).isValid,
      isFalse,
    );
    expect(
      const AppConfig(
        url: 'https://test.supabase.co',
        publishableKey: 'sb_publishable_example',
        authRedirectUrl: 'http://localhost:7357/',
      ).isValid,
      isTrue,
    );
  });
}

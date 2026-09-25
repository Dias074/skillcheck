class AppConfig {
  const AppConfig({
    required this.url,
    required this.publishableKey,
    required this.authRedirectUrl,
  });
  const AppConfig.fromEnvironment()
    : url = const String.fromEnvironment('SUPABASE_URL'),
      publishableKey = const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
      authRedirectUrl = const String.fromEnvironment(
        'AUTH_REDIRECT_URL',
        defaultValue: 'com.dias.skillcheck://auth-callback/',
      );

  final String url;
  final String publishableKey;
  final String authRedirectUrl;

  bool get isValid {
    final uri = Uri.tryParse(url);
    final redirect = Uri.tryParse(authRedirectUrl);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.endsWith('.supabase.co') &&
        !uri.host.contains('YOUR_PROJECT') &&
        publishableKey.startsWith('sb_publishable_') &&
        !publishableKey.contains('REPLACE_') &&
        redirect != null &&
        redirect.hasScheme;
  }

  String get recoveryRedirectUrl =>
      Uri.parse(authRedirectUrl)
          .replace(queryParameters: {'flow': 'recovery'})
          .toString();
}

import 'package:flutter/material.dart';

import 'theme/app_theme.dart';

class SetupScreen extends StatelessWidget {
  const SetupScreen({this.failed = false, super.key});
  final bool failed;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SkillCheck',
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SkillCheck setup',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    failed
                        ? 'Unable to initialize the connection. Check your configuration and connection, then restart.'
                        : 'Supabase client configuration is missing or invalid.',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Copy config/supabase.example.json to config/supabase.local.json and set your project URL and publishable client key.',
                  ),
                  const SizedBox(height: 12),
                  const SelectableText(
                    'flutter run -d chrome --web-port 7357 --dart-define-from-file=config/supabase.local.json',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'See docs/supabase-setup.md for database and authentication setup.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

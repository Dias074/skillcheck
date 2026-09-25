import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/theme_mode_provider.dart';
import '../../../core/errors/app_failure.dart';
import '../../../shared/widgets/page_content.dart';
import '../../auth/application/auth_providers.dart';
import '../data/profile_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).user;
    final profile = ref.watch(profileProvider);
    final operation = ref.watch(authControllerProvider);
    return PageContent(
      title: 'Profile',
      description: 'Your account and preferences.',
      children: [
        Text('Account', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(user?.email ?? ''),
        const SizedBox(height: 8),
        profile.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, stack) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(friendlyFailure(error, 'profile UI').message),
              TextButton(
                onPressed: () => ref.invalidate(profileProvider),
                child: const Text('Retry profile'),
              ),
            ],
          ),
          data: (value) => Text(
            value == null || value.displayName.isEmpty
                ? 'Display name not available.'
                : value.displayName,
          ),
        ),
        const SizedBox(height: 16),
        if (operation.hasError)
          Text(friendlyFailure(operation.error!, 'logout').message),
        OutlinedButton(
          onPressed: operation.isLoading
              ? null
              : () => ref.read(authControllerProvider.notifier).logout(),
          child: Text(operation.isLoading ? 'Please wait…' : 'Log out'),
        ),
        const SizedBox(height: 24),
        Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        DropdownButtonFormField<ThemeMode>(
          initialValue: ref.watch(themeModeProvider),
          decoration: const InputDecoration(
            labelText: 'Theme',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
            DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
            DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
          ],
          onChanged: (mode) {
            if (mode != null) {
              ref.read(themeModeProvider.notifier).setThemeMode(mode);
            }
          },
        ),
        const SizedBox(height: 8),
        const Text('Theme selection applies for this session.'),
      ],
    );
  }
}

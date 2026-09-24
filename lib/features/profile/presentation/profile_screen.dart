import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/theme_mode_provider.dart';
import '../../../shared/widgets/feature_placeholder.dart';
import '../../../shared/widgets/page_content.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => PageContent(
    title: 'Profile',
    description: 'Make SkillCheck feel like your own.',
    children: [
      const FeaturePlaceholder(
        icon: Icons.person_outline,
        title: 'Your account is coming soon',
        description: 'Sign-in and personal profiles will be available in a future update.',
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

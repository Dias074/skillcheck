import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/feature_placeholder.dart';
import '../../../shared/widgets/page_content.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) => PageContent(
    title: 'Welcome to SkillCheck',
    description: 'Understand your knowledge. Build your next learning step.',
    children: [
      FeaturePlaceholder(
        icon: Icons.school_outlined,
        title: 'Your learning journey starts here',
        description: 'Assessments, learning insights and practice are coming soon. This foundation preview lets you explore the app navigation.',
        action: FilledButton.icon(
          onPressed: () => context.go('/assessments'),
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Explore assessments'),
        ),
      ),
    ],
  );
}

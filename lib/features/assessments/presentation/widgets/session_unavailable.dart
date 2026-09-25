import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/feature_placeholder.dart';
import '../../../../shared/widgets/page_content.dart';

class SessionUnavailable extends StatelessWidget {
  const SessionUnavailable({super.key});

  @override
  Widget build(BuildContext context) => PageContent(
    title: 'No result available',
    description: 'Attempts are kept only while the app is running.',
    children: [
      FeaturePlaceholder(
        icon: Icons.quiz_outlined,
        title: 'Choose an assessment',
        description: 'Start or resume an assessment from the categories page.',
        action: FilledButton(
          onPressed: () => context.go('/assessments'),
          child: const Text('Back to assessments'),
        ),
      ),
    ],
  );
}

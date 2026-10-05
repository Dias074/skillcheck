import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/feature_placeholder.dart';
import '../../../../shared/widgets/page_content.dart';

class SessionUnavailable extends StatelessWidget {
  const SessionUnavailable({super.key, this.practice = false});
  final bool practice;

  @override
  Widget build(BuildContext context) => PageContent(
    title: 'No result available',
    description: 'Attempts are kept only while the app is running.',
    children: [
      FeaturePlaceholder(
        icon: Icons.quiz_outlined,
        title: practice ? 'Start a practice session' : 'Choose an assessment',
        description: practice
            ? 'Return to Weak Areas in Progress to practise.'
            : 'Start or resume an assessment from the categories page.',
        action: FilledButton(
          onPressed: () => context.go(practice ? '/progress' : '/assessments'),
          child: Text(practice ? 'Back to Progress' : 'Back to assessments'),
        ),
      ),
    ],
  );
}

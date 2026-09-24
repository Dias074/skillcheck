import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_placeholder.dart';
import '../../../shared/widgets/page_content.dart';

class AssessmentsScreen extends StatelessWidget {
  const AssessmentsScreen({super.key});
  @override
  Widget build(BuildContext context) => const PageContent(
    title: 'Assessments',
    description: 'Discover what you know and what to learn next.',
    children: [
      FeaturePlaceholder(
        icon: Icons.quiz_outlined,
        title: 'Assessments are coming soon',
        description: 'Planned subjects: English, Kazakh, Russian, Logic & Reasoning, and Programming. Quizzes are not available in this preview.',
      ),
    ],
  );
}

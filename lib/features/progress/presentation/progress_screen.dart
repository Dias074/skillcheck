import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_placeholder.dart';
import '../../../shared/widgets/page_content.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});
  @override
  Widget build(BuildContext context) => const PageContent(
    title: 'Progress',
    description: 'See your learning over time.',
    children: [
      FeaturePlaceholder(
        icon: Icons.insights_outlined,
        title: 'Progress tracking is coming soon',
        description: 'Once assessments and history are available, your results will appear here. No assessment data has been collected yet.',
      ),
    ],
  );
}

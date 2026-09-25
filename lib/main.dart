import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/setup_screen.dart';
import 'core/config/app_config.dart';
import 'core/errors/app_failure.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const config = AppConfig.fromEnvironment();
  if (!config.isValid) {
    runApp(const SetupScreen());
    return;
  }
  try {
    await Supabase.initialize(
      url: config.url,
      publishableKey: config.publishableKey,
      debug: false,
    );
    runApp(const ProviderScope(child: SkillCheckApp()));
  } catch (error) {
    friendlyFailure(error, 'initialization');
    runApp(const SetupScreen(failed: true));
  }
}

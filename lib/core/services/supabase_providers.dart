import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

final appConfigProvider = Provider((ref) => const AppConfig.fromEnvironment());
final supabaseClientProvider = Provider((ref) => Supabase.instance.client);

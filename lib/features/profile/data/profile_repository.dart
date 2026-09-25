import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/services/supabase_providers.dart';
import '../../auth/application/auth_providers.dart';

class UserProfile {
  const UserProfile({required this.id, required this.displayName});
  final String id;
  final String displayName;
}

abstract interface class ProfileRepository {
  Future<UserProfile?> fetchProfile(String userId);
}

class SupabaseProfileRepository implements ProfileRepository {
  const SupabaseProfileRepository(this.client);
  final SupabaseClient client;
  @override
  Future<UserProfile?> fetchProfile(String userId) =>
      guarded('profile', () async {
        final row = await client
            .from('profiles')
            .select('id, display_name')
            .eq('id', userId)
            .maybeSingle()
            .timeout(const Duration(seconds: 20));
        return row == null
            ? null
            : UserProfile(
                id: row['id'] as String,
                displayName: row['display_name'] as String,
              );
      });
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => SupabaseProfileRepository(ref.watch(supabaseClientProvider)),
);
final profileProvider = FutureProvider<UserProfile?>((ref) async {
  final userId = ref.watch(authStateProvider.select((state) => state.user?.id));
  if (userId == null) return null;
  return ref.watch(profileRepositoryProvider).fetchProfile(userId);
});

import 'local_config.dart';

class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: LocalConfig.supabaseUrl,
  );
  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: LocalConfig.supabaseAnonKey,
  );
  static const redirectUrl = String.fromEnvironment(
    'SUPABASE_AUTH_REDIRECT_URL',
    defaultValue: LocalConfig.supabaseAuthRedirectUrl,
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}

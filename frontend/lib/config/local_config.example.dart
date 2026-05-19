class LocalConfig {
  static const supabaseUrl = 'https://your-project.supabase.co';
  static const supabaseAnonKey = 'your-supabase-publishable-or-anon-key';
  static const supabaseAuthRedirectUrl =
      'com.example.worthit_app://login-callback';

  // Leave empty to use localhost on iOS/web/desktop and 10.0.2.2 on Android emulator.
  static const apiBaseUrl = 'http://192.168.1.10:8000';
}

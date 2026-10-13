/// Configuration comes from --dart-define, never from committed secrets.
/// Only the Supabase URL and the anon/publishable key belong here.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Development mode: no Supabase configured, sample data only.
  static bool get devMode => supabaseUrl.isEmpty || supabaseAnonKey.isEmpty;
}

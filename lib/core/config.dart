/// Configuration comes from --dart-define, never from committed secrets.
/// Only the Supabase URL and the anon/publishable key belong here.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Optional. Support and policy links only appear in the app when these are set.
  static const supportEmail = String.fromEnvironment('SUPPORT_EMAIL');
  static const supportWhatsapp = String.fromEnvironment('SUPPORT_WHATSAPP'); // digits with country code, e.g. 2348012345678
  static const termsUrl = String.fromEnvironment('TERMS_URL');
  static const privacyUrl = String.fromEnvironment('PRIVACY_URL');

  /// Development mode: no Supabase configured, sample data only.
  static bool get devMode => supabaseUrl.isEmpty || supabaseAnonKey.isEmpty;
}

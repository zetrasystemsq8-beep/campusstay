/// Configuration comes from --dart-define, never from committed secrets.
/// Only the Supabase URL and the anon/publishable key belong here.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Optional. Support and policy links only appear in the app when these are set.
  static const supportEmail = String.fromEnvironment('SUPPORT_EMAIL');
  static const supportWhatsapp = String.fromEnvironment('SUPPORT_WHATSAPP'); // digits with country code, e.g. 2348012345678
  /// Optional link to the app (for example its Play Store page), added to shared listings.
  static const appLink = String.fromEnvironment('APP_LINK');
  static const termsUrl = String.fromEnvironment('TERMS_URL');
  static const privacyUrl = String.fromEnvironment('PRIVACY_URL');

  /// Map tiles. The default is OpenStreetMap's public server, which is fine for testing but
  /// not for heavy use. Set MAP_TILE_URL (and MAP_ATTRIBUTION) to a tile provider you have an account with.
  static const mapTileUrl = String.fromEnvironment('MAP_TILE_URL', defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
  static const mapAttribution = String.fromEnvironment('MAP_ATTRIBUTION', defaultValue: '© OpenStreetMap contributors');

  /// Development mode: no Supabase configured, sample data only.
  static bool get devMode => supabaseUrl.isEmpty || supabaseAnonKey.isEmpty;
}

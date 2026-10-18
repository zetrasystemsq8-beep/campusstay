import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config.dart';
import 'offline_cache.dart';
import '../core/errors.dart';
import '../features/legal/legal_screens.dart';

class AuthService {
  static bool _demoSignedIn = false;
  static String _demoRole = 'student';

  static bool get signedIn =>
      AppConfig.devMode ? _demoSignedIn : Supabase.instance.client.auth.currentSession != null;

  static String get email =>
      AppConfig.devMode ? 'demo@campusstay.local' : (Supabase.instance.client.auth.currentUser?.email ?? '');

  /// Role comes from the server-side profile, never from the client's claim.
  static Future<String> role() async {
    if (AppConfig.devMode) return _demoRole;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return 'student';
    final row = await Net.run(() => Supabase.instance.client.from('cs_profiles').select('role').eq('id', uid).single());
    return row['role'] as String;
  }

  static void startDemo(String role) {
    _demoSignedIn = true;
    _demoRole = role;
  }

  static Future<bool> signUp(String email, String password, String role, String name) async {
    final res = await Net.run(() => Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          data: {'role': role, 'full_name': name, 'terms_version': kTermsVersion},
        ));
    return res.session != null; // false => email confirmation required
  }

  static Future<void> signIn(String email, String password) =>
      Net.run(() => Supabase.instance.client.auth.signInWithPassword(email: email, password: password));

  static Future<void> resetPassword(String email) =>
      Net.run(() => Supabase.instance.client.auth.resetPasswordForEmail(email));

  /// Sends a one-time code to the email. The email template in Supabase must contain {{ .Token }}.
  static Future<void> sendResetCode(String email) => Net.run(() => Supabase.instance.client.auth.resetPasswordForEmail(email));

  /// Proves the code, sets the new password, then signs out so the person logs in fresh.
  static Future<void> resetWithCode(String email, String code, String newPassword) => Net.run(() async {
        final c = Supabase.instance.client;
        await c.auth.verifyOTP(email: email, token: code, type: OtpType.recovery);
        await c.auth.updateUser(UserAttributes(password: newPassword));
        await c.auth.signOut();
      });

  static Future<void> signOut() async {
    _demoSignedIn = false;
    await PropertyCache.clear();
    if (!AppConfig.devMode) await Net.run(() => Supabase.instance.client.auth.signOut());
  }
}

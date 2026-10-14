import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config.dart';
import '../core/errors.dart';

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
    final row = await Net.run(() => Supabase.instance.client.from('profiles').select('role').eq('id', uid).single());
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
          data: {'role': role, 'full_name': name},
        ));
    return res.session != null; // false => email confirmation required
  }

  static Future<void> signIn(String email, String password) =>
      Net.run(() => Supabase.instance.client.auth.signInWithPassword(email: email, password: password));

  static Future<void> resetPassword(String email) =>
      Net.run(() => Supabase.instance.client.auth.resetPasswordForEmail(email));

  static Future<void> signOut() async {
    _demoSignedIn = false;
    if (!AppConfig.devMode) await Net.run(() => Supabase.instance.client.auth.signOut());
  }
}

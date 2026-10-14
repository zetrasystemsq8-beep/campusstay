import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/errors.dart';
import 'auth_service.dart';
import 'profile_models.dart';

abstract class ProfileRepository {
  Future<ProfileData> load();
  Future<void> save(String fullName, String phone);
  Future<void> changePassword(String current, String next);
  Future<List<AppNotification>> notifications();
  Future<void> markRead(String id);
  Future<void> markAllRead();
  Future<List<BlockedPerson>> blocked();
  Future<void> unblock(String id);
}

/// Development mode: in memory only.
class SampleProfileRepository implements ProfileRepository {
  String _name = '';
  String _phone = '';

  @override
  Future<ProfileData> load() async =>
      ProfileData(id: 'demo', email: AuthService.email, role: await AuthService.role(), fullName: _name, phone: _phone.isEmpty ? null : _phone);

  @override
  Future<void> save(String fullName, String phone) async {
    _name = fullName;
    _phone = phone;
  }

  @override
  Future<void> changePassword(String current, String next) async =>
      throw const AppException(AppErrorKind.invalid, detail: 'Password changes need a real account. Connect Supabase first.');

  @override
  Future<List<AppNotification>> notifications() async => [];
  @override
  Future<void> markRead(String id) async {}
  @override
  Future<void> markAllRead() async {}
  @override
  Future<List<BlockedPerson>> blocked() async => [];
  @override
  Future<void> unblock(String id) async {}
}

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseClient get _c => Supabase.instance.client;
  User get _user {
    final u = _c.auth.currentUser;
    if (u == null) throw const AuthException('Please sign in first.');
    return u;
  }

  @override
  Future<ProfileData> load() async {
    final u = _user;
    final r = await _c.from('cs_profiles').select('full_name,phone,role,is_suspended').eq('id', u.id).single();
    return ProfileData(
      id: u.id,
      email: u.email ?? '',
      role: r['role'] as String,
      fullName: r['full_name'] as String?,
      phone: r['phone'] as String?,
      suspended: r['is_suspended'] as bool? ?? false,
    );
  }

  @override
  Future<void> save(String fullName, String phone) async {
    // .single() makes a missing or blocked row an error instead of a silent no-op.
    await _c.from('cs_profiles').update({'full_name': fullName, 'phone': phone.isEmpty ? null : phone}).eq('id', _user.id).select('id').single();
  }

  @override
  Future<void> changePassword(String current, String next) async {
    final email = _user.email;
    if (email == null) throw const AuthException('Please sign in first.');
    await _c.auth.signInWithPassword(email: email, password: current); // proves it is really them
    await _c.auth.updateUser(UserAttributes(password: next));
  }

  @override
  Future<List<AppNotification>> notifications() async {
    final rows = await _c.from('cs_notifications').select('id,kind,title,body,read_at,created_at').eq('user_id', _user.id).order('created_at', ascending: false).limit(50);
    return rows
        .map<AppNotification>((r) => AppNotification(r['id'] as String, r['kind'] as String, r['title'] as String, r['body'] as String?, r['read_at'] != null,
            DateTime.parse(r['created_at'] as String).toLocal()))
        .toList();
  }

  @override
  Future<void> markRead(String id) async {
    await _c.from('cs_notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id).eq('user_id', _user.id);
  }

  @override
  Future<void> markAllRead() async {
    await _c.from('cs_notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('user_id', _user.id).isFilter('read_at', null);
  }

  @override
  Future<List<BlockedPerson>> blocked() async {
    final rows = await _c.from('cs_blocks').select('blocked_id,created_at').eq('blocker_id', _user.id).order('created_at', ascending: false);
    return rows.map<BlockedPerson>((r) => BlockedPerson(r['blocked_id'] as String, DateTime.parse(r['created_at'] as String).toLocal())).toList();
  }

  @override
  Future<void> unblock(String id) async {
    await _c.from('cs_blocks').delete().eq('blocker_id', _user.id).eq('blocked_id', id);
  }
}

class GuardedProfileRepository implements ProfileRepository {
  final ProfileRepository _r;
  GuardedProfileRepository(this._r);

  @override
  Future<ProfileData> load() => Net.run(() => _r.load());
  @override
  Future<void> save(String fullName, String phone) => Net.run(() => _r.save(fullName, phone));
  @override
  Future<void> changePassword(String current, String next) => Net.run(() => _r.changePassword(current, next));
  @override
  Future<List<AppNotification>> notifications() => Net.run(() => _r.notifications());
  @override
  Future<void> markRead(String id) => Net.run(() => _r.markRead(id));
  @override
  Future<void> markAllRead() => Net.run(() => _r.markAllRead());
  @override
  Future<List<BlockedPerson>> blocked() => Net.run(() => _r.blocked());
  @override
  Future<void> unblock(String id) => Net.run(() => _r.unblock(id));
}

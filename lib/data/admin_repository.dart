import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_models.dart';
import 'landlord_models.dart';
import 'property_extras.dart';

/// Every method here is also enforced by Row Level Security or admin-only
/// database functions. Hiding a button is never the only protection.
abstract class AdminRepository {
  Future<AdminStats> stats();
  Future<List<LandlordListing>> pendingListings();
  Future<void> moderate(String id, String decision, String note);
  Future<void> setSuspension(String userId, bool suspended, String reason);
  Future<List<AdminReport>> reports({bool openOnly = true});
  Future<void> resolveReport(String id, String status, String note);
  Future<List<VerificationItem>> verifications();
  Future<String> signedDocUrl(String path);
  Future<void> reviewVerification(String id, bool approved, String note);
  Future<List<LeadItem>> leads();
  Future<void> setLeadStatus(String id, String status);
  Future<List<AuditItem>> audit();
  Future<void> deleteReview(String id, String note);
  Future<Map<String, List<(String, int)>>> breakdown();
  Future<void> saveSchool(String? id, String name, String shortName, String city, String state, String kind);
}

/// Development mode has no admin account, so everything is empty.
class SampleAdminRepository implements AdminRepository {
  @override
  Future<AdminStats> stats() async => const AdminStats(0, 0, 0, 0, 0, 0, 0);
  @override
  Future<List<LandlordListing>> pendingListings() async => [];
  @override
  Future<void> moderate(String id, String decision, String note) async {}
  @override
  Future<void> setSuspension(String userId, bool suspended, String reason) async {}
  @override
  Future<List<AdminReport>> reports({bool openOnly = true}) async => [];
  @override
  Future<void> resolveReport(String id, String status, String note) async {}
  @override
  Future<List<VerificationItem>> verifications() async => [];
  @override
  Future<String> signedDocUrl(String path) async => '';
  @override
  Future<void> reviewVerification(String id, bool approved, String note) async {}
  @override
  Future<List<LeadItem>> leads() async => [];
  @override
  Future<void> setLeadStatus(String id, String status) async {}
  @override
  Future<List<AuditItem>> audit() async => [];
  @override
  Future<void> deleteReview(String id, String note) async {}
  @override
  Future<Map<String, List<(String, int)>>> breakdown() async => {};
  @override
  Future<void> saveSchool(String? id, String name, String shortName, String city, String state, String kind) async {}
}

class SupabaseAdminRepository implements AdminRepository {
  SupabaseClient get _c => Supabase.instance.client;

  static const _sel = 'id,owner_id,title,description,area,rent_ngn,rent_period,room_type,distance_km,extra_fees_note,'
      'moderation_status,availability_status,verification_level,expires_at,views_count,moderation_note,university_id,$kExtrasColumns,'
      'universities:cs_universities(short_name),property_photos:cs_property_photos(id,storage_path,sort_order),property_amenities:cs_property_amenities(amenities:cs_amenities(code))';

  @override
  Future<AdminStats> stats() async {
    final r = await _c.rpc('cs_admin_stats') as Map;
    int n(String k) => (r[k] as num?)?.toInt() ?? 0;
    return AdminStats(n('pending_listings'), n('live_listings'), n('total_listings'), n('open_reports'), n('pending_verifications'), n('new_leads'), n('users'));
  }

  @override
  Future<List<LandlordListing>> pendingListings() async {
    final rows = await _c.from('cs_properties').select(_sel).eq('moderation_status', 'pending').order('updated_at').limit(50);
    return rows
        .map<LandlordListing>((m) => LandlordListing.fromMap(m, (p) => _c.storage.from('cs-property-photos').getPublicUrl(p)))
        .toList();
  }

  @override
  Future<void> moderate(String id, String decision, String note) async {
    await _c.rpc('cs_admin_moderate_listing', params: {'p_property_id': id, 'p_decision': decision, 'p_note': note});
  }

  @override
  Future<void> setSuspension(String userId, bool suspended, String reason) async {
    await _c.rpc('cs_admin_set_suspension', params: {'p_user_id': userId, 'p_suspended': suspended, 'p_reason': reason});
  }

  @override
  Future<List<AdminReport>> reports({bool openOnly = true}) async {
    var q = _c.from('cs_reports').select('id,target_type,target_id,reason,details,status,created_at');
    if (openOnly) q = q.inFilter('status', ['open', 'reviewing']);
    final rows = await q.order('created_at', ascending: false).limit(100);
    final propIds = rows.where((r) => r['target_type'] == 'property').map((r) => r['target_id'] as String).toSet().toList();
    final titles = <String, String>{};
    if (propIds.isNotEmpty) {
      final props = await _c.from('cs_properties').select('id,title').inFilter('id', propIds);
      for (final p in props) {
        titles[p['id'] as String] = p['title'] as String;
      }
    }
    return rows
        .map<AdminReport>((r) => AdminReport(r['id'] as String, r['target_type'] as String, r['target_id'] as String, r['reason'] as String,
            r['details'] as String?, r['status'] as String, DateTime.parse(r['created_at'] as String).toLocal(), titles[r['target_id']]))
        .toList();
  }

  @override
  Future<void> resolveReport(String id, String status, String note) async {
    await _c.rpc('cs_admin_resolve_report', params: {'p_report_id': id, 'p_status': status, 'p_note': note});
  }

  @override
  Future<List<VerificationItem>> verifications() async {
    final rows = await _c
        .from('cs_verification_submissions')
        .select('id,user_id,doc_type,storage_path,created_at,properties:cs_properties(title)')
        .eq('status', 'pending')
        .order('created_at')
        .limit(100);
    return rows.map<VerificationItem>((r) {
      final p = r['properties'];
      return VerificationItem(r['id'] as String, r['user_id'] as String, r['doc_type'] as String, r['storage_path'] as String,
          p is Map ? p['title'] as String : 'Listing', DateTime.parse(r['created_at'] as String).toLocal());
    }).toList();
  }

  @override
  Future<String> signedDocUrl(String path) => _c.storage.from('cs-verification-docs').createSignedUrl(path, 300);

  @override
  Future<void> reviewVerification(String id, bool approved, String note) async {
    await _c.rpc('cs_admin_review_verification', params: {'p_submission_id': id, 'p_approved': approved, 'p_note': note});
  }

  @override
  Future<List<LeadItem>> leads() async {
    final rows = await _c.from('cs_landlord_submissions').select().inFilter('status', ['new', 'contacted']).order('created_at', ascending: false).limit(100);
    return rows
        .map<LeadItem>((r) => LeadItem(r['id'] as String, r['name'] as String, r['phone'] as String, r['school_or_area'] as String,
            r['room_type'] as String, (r['rent_ngn'] as num?)?.toInt(), r['description'] as String?, r['status'] as String, DateTime.parse(r['created_at'] as String).toLocal()))
        .toList();
  }

  @override
  Future<void> setLeadStatus(String id, String status) async {
    await _c.rpc('cs_admin_set_lead_status', params: {'p_id': id, 'p_status': status});
  }

  @override
  Future<List<AuditItem>> audit() async {
    final rows = await _c.from('cs_audit_events').select('id,action,target_type,target_id,details,created_at').order('created_at', ascending: false).limit(100);
    return rows
        .map<AuditItem>((r) => AuditItem((r['id'] as num).toInt(), r['action'] as String, r['target_type'] as String, r['target_id'] as String?,
            Map<String, dynamic>.from((r['details'] as Map?) ?? {}), DateTime.parse(r['created_at'] as String).toLocal()))
        .toList();
  }

  @override
  Future<void> deleteReview(String id, String note) async {
    await _c.rpc('cs_admin_delete_review', params: {'p_review_id': id, 'p_note': note});
  }

  @override
  Future<Map<String, List<(String, int)>>> breakdown() async {
    final r = await _c.rpc('cs_admin_breakdown') as Map;
    return {
      for (final k in r.keys.cast<String>())
        k: [for (final e in (r[k] as List).cast<Map>()) ((e['label'] ?? '') as String, (e['n'] as num).toInt())],
    };
  }

  @override
  Future<void> saveSchool(String? id, String name, String shortName, String city, String state, String kind) async {
    final row = {'name': name, 'short_name': shortName, 'city': city, 'state': state, 'kind': kind};
    if (id == null) {
      await _c.from('cs_universities').insert(row);
    } else {
      await _c.from('cs_universities').update(row).eq('id', id);
    }
  }
}

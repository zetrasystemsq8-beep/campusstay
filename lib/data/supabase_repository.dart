import 'package:supabase_flutter/supabase_flutter.dart';
import 'location_models.dart';
import 'models.dart';
import 'repository.dart';

class SupabaseRepository implements Repository {
  SupabaseClient get _c => Supabase.instance.client;
  String get _uid {
    final u = _c.auth.currentUser;
    if (u == null) throw const AuthException('Please sign in first.');
    return u.id;
  }

  static const _sel =
      'id,title,description,area,rent_ngn,rent_period,room_type,distance_km,verification_level,extra_fees_note,$kExtrasColumns,approx_lat,approx_lng,'
      'universities:cs_universities(short_name),property_photos:cs_property_photos(storage_path,sort_order),property_amenities:cs_property_amenities(amenities:cs_amenities(code))';

  String _photo(String path) => _c.storage.from('cs-property-photos').getPublicUrl(path);
  Property _p(Map<String, dynamic> m) => Property.fromMap(m, _photo);

  /// Shared by list search and map search. RLS already limits rows to approved, available, unexpired listings.
  PostgrestFilterBuilder<PostgrestList> _filtered(SearchFilter f) {
    var q = _c.from('cs_properties').select(_sel);
    if (f.minRent != null) q = q.gte('rent_ngn', f.minRent!);
    if (f.maxRent != null) q = q.lte('rent_ngn', f.maxRent!);
    if (f.roomType != null) q = q.eq('room_type', f.roomType!);
    if (f.universityId != null) q = q.eq('university_id', f.universityId!);
    if (f.furnishing != null) q = q.eq('furnishing', f.furnishing!);
    if (f.minBedrooms != null) q = q.gte('bedrooms', f.minBedrooms!);
    if (f.forGender != null) q = q.inFilter('gender_preference', ['any', '${f.forGender}_only']);
    if (f.amenities.isNotEmpty) q = q.contains('amenity_codes', f.amenities.toList());
    final text = f.query.trim().replaceAll(RegExp(r'[%_,()]'), ' ');
    if (text.isNotEmpty) q = q.or('title.ilike.%$text%,area.ilike.%$text%');
    return q;
  }

  @override
  Future<List<Property>> search(SearchFilter f, {int page = 0}) async {
    final from = page * Repository.pageSize;
    final rows = await _filtered(f).order('created_at', ascending: false).range(from, from + Repository.pageSize - 1);
    return rows.map<Property>((r) => _p(r)).toList();
  }

  @override
  Future<List<Property>> mapListings(SearchFilter f, {required double south, required double west, required double north, required double east}) async {
    final rows = await _filtered(f).gte('approx_lat', south).lte('approx_lat', north).gte('approx_lng', west).lte('approx_lng', east).limit(100);
    return rows.map<Property>((r) => _p(r)).toList();
  }

  @override
  Future<ExactLocation?> exactLocation(String propertyId) async {
    // RLS returns a row only to the owner, admins, and students whose viewing was confirmed.
    final r = await _c.from('cs_property_locations').select('lat,lng,address_line').eq('property_id', propertyId).maybeSingle();
    if (r == null) return null;
    return ExactLocation((r['lat'] as num).toDouble(), (r['lng'] as num).toDouble(), (r['address_line'] ?? '') as String);
  }

  @override
  Future<String> contactStatus(String propertyId) async => (await _c.rpc('cs_contact_status', params: {'p_property_id': propertyId})) as String;

  @override
  Future<String> revealPhone(String propertyId) async => (await _c.rpc('cs_reveal_contact', params: {'p_property_id': propertyId})) as String;

  @override
  Future<Property> property(String id) async {
    final row = await _c.from('cs_properties').select(_sel).eq('id', id).single();
    return _p(row);
  }

  @override
  Future<Set<String>> favouriteIds() async {
    final rows = await _c.from('cs_favourites').select('property_id').eq('user_id', _uid);
    return rows.map<String>((r) => r['property_id'] as String).toSet();
  }

  @override
  Future<List<Property>> favourites() async {
    final rows = await _c.from('cs_favourites').select('properties:cs_properties($_sel)').eq('user_id', _uid);
    return rows
        .map((r) => r['properties'])
        .whereType<Map<String, dynamic>>()
        .map<Property>(_p)
        .toList();
  }

  @override
  Future<void> setFavourite(String propertyId, bool on) async {
    if (on) {
      await _c.from('cs_favourites').upsert({'user_id': _uid, 'property_id': propertyId});
    } else {
      await _c.from('cs_favourites').delete().eq('user_id', _uid).eq('property_id', propertyId);
    }
  }

  @override
  Future<void> requestViewing(String propertyId, DateTime preferred, String note) async {
    await _c.from('cs_viewing_requests').insert({
      'property_id': propertyId,
      'student_id': _uid,
      'preferred_at': preferred.toUtc().toIso8601String(),
      'note': note,
    });
  }

  @override
  Future<void> sendEnquiry(String propertyId, String message) async {
    await _c.rpc('cs_start_enquiry', params: {'p_property_id': propertyId, 'p_body': message});
  }

  @override
  Future<List<Conversation>> conversations() async {
    final rows = await _c
        .from('cs_conversations')
        .select('id,student_id,landlord_id,properties:cs_properties(title)')
        .order('created_at', ascending: false);
    final me = _uid;
    return rows.map<Conversation>((r) {
      final p = r['properties'];
      final other = r['student_id'] == me ? r['landlord_id'] : r['student_id'];
      return Conversation(r['id'] as String, p is Map ? p['title'] as String : 'Enquiry', other as String?);
    }).toList();
  }

  @override
  Future<List<ChatMessage>> messages(String conversationId) async {
    final rows = await _c
        .from('cs_messages')
        .select('id,sender_id,body,created_at')
        .eq('conversation_id', conversationId)
        .order('created_at');
    final me = _uid;
    return rows
        .map<ChatMessage>((r) => ChatMessage(r['id'] as String, r['body'] as String, r['sender_id'] == me,
            DateTime.parse(r['created_at'] as String).toLocal()))
        .toList();
  }

  @override
  Future<void> sendMessage(String conversationId, String body) async {
    await _c.from('cs_messages').insert({'conversation_id': conversationId, 'sender_id': _uid, 'body': body});
  }

  @override
  Future<void> blockUser(String userId) async {
    await _c.from('cs_blocks').upsert({'blocker_id': _uid, 'blocked_id': userId});
  }

  @override
  Future<void> report(String targetType, String targetId, String reason, String details) async {
    await _c.from('cs_reports').insert({
      'reporter_id': _uid,
      'target_type': targetType,
      'target_id': targetId,
      'reason': reason,
      'details': details,
    });
  }
}

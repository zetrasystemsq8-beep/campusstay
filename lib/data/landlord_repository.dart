import 'dart:math';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/errors.dart';
import 'amenity_catalog.dart';
import 'landlord_models.dart';
import 'location_models.dart';
import 'property_extras.dart';

abstract class LandlordRepository {
  Future<List<University>> universities();
  Future<DashboardStats> stats();
  Future<List<LandlordListing>> myListings();
  Future<LandlordListing> myListing(String id);
  Future<String> saveDraft(String? id, ListingInput input);
  Future<PhotoRef> addPhoto(String propertyId, Uint8List bytes, String fileName, int sortOrder);
  Future<void> removePhoto(String propertyId, PhotoRef photo);
  Future<void> setAmenities(String propertyId, List<String> codes);
  Future<void> uploadVerificationDoc(String propertyId, String docType, Uint8List bytes, String fileName);
  Future<void> submitForReview(String propertyId);
  Future<void> setAvailability(String id, String status);
  Future<void> renew(String id);
  Future<void> delete(String id);
  Future<List<ViewingRequestItem>> viewingRequests();
  Future<void> decideViewing(String id, String status);
  Future<ExactLocation?> myLocation(String propertyId);
  Future<void> saveLocation(String propertyId, double lat, double lng, String addressLine);
  Future<void> clearLocation(String propertyId);
}

String _rid() => DateTime.now().microsecondsSinceEpoch.toRadixString(36) + Random().nextInt(1 << 30).toRadixString(36);

String _ext(String name) {
  final e = name.contains('.') ? name.split('.').last.toLowerCase() : 'jpg';
  return const ['jpg', 'jpeg', 'png', 'webp', 'pdf'].contains(e) ? e : 'jpg';
}

String _mime(String ext) => switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      _ => 'image/jpeg',
    };

/// Development mode: everything is in memory. Nothing is uploaded or reviewed.
class SampleLandlordRepository implements LandlordRepository {
  final _list = <LandlordListing>[];
  final _unis = const [
    University('u1', 'Ekiti State University', 'EKSU', city: 'Ado-Ekiti', state: 'Ekiti'),
    University('u2', 'Federal University Oye-Ekiti', 'FUOYE', city: 'Oye-Ekiti', state: 'Ekiti'),
    University('u3', 'University of Lagos', 'UNILAG', city: 'Lagos', state: 'Lagos'),
    University('u4', 'Yaba College of Technology', 'YABATECH', city: 'Yaba', state: 'Lagos', kind: 'polytechnic'),
    University('u5', 'Federal College of Education, Abeokuta', 'FCEABEOKUTA', city: 'Abeokuta', state: 'Ogun', kind: 'college_of_education'),
  ];

  LandlordListing _get(String id) => _list.firstWhere((l) => l.id == id);

  @override
  Future<List<University>> universities() async => _unis;

  @override
  Future<DashboardStats> stats() async => DashboardStats(
      _list.length, _list.where((l) => l.isActive).length, _list.where((l) => l.moderation == 'pending').length, 0, 0);

  @override
  Future<List<LandlordListing>> myListings() async => [..._list];

  @override
  Future<LandlordListing> myListing(String id) async => _get(id);

  @override
  Future<String> saveDraft(String? id, ListingInput i) async {
    final uni = _unis.where((u) => u.id == i.universityId).firstOrNull;
    if (id == null) {
      final l = LandlordListing(
        id: 'L${_list.length + 1}',
        title: i.title,
        description: i.description,
        area: i.area,
        university: uni?.shortName ?? '',
        universityId: uni?.id,
        extras: i.extras,
        rentPeriod: i.rentPeriod,
        roomType: i.roomType,
        moderation: 'draft',
        availability: 'available',
        verification: 'unverified',
        rentNgn: i.rentNgn,
        distanceKm: i.distanceKm,
        extraFees: i.extraFees,
        photos: [],
        amenities: [],
      );
      _list.add(l);
      return l.id;
    }
    final l = _get(id);
    l
      ..title = i.title
      ..description = i.description
      ..area = i.area
      ..university = uni?.shortName ?? ''
      ..universityId = uni?.id
      ..extras = i.extras
      ..rentPeriod = i.rentPeriod
      ..roomType = i.roomType
      ..rentNgn = i.rentNgn
      ..distanceKm = i.distanceKm
      ..extraFees = i.extraFees;
    return id;
  }

  @override
  Future<PhotoRef> addPhoto(String propertyId, Uint8List bytes, String fileName, int sortOrder) async {
    final ref = PhotoRef(_rid(), 'dev/${_rid()}', null);
    final l = _get(propertyId);
    l.photos = [...l.photos, ref];
    return ref;
  }

  @override
  Future<void> removePhoto(String propertyId, PhotoRef photo) async {
    final l = _get(propertyId);
    l.photos = l.photos.where((p) => p.id != photo.id).toList();
  }

  @override
  Future<void> setAmenities(String propertyId, List<String> codes) async => _get(propertyId).amenities = [...codes];

  @override
  Future<void> uploadVerificationDoc(String propertyId, String docType, Uint8List bytes, String fileName) async {
    final l = _get(propertyId);
    if (l.verification == 'unverified') l.verification = 'pending';
  }

  @override
  Future<void> submitForReview(String propertyId) async => _get(propertyId).moderation = 'pending';

  @override
  Future<void> setAvailability(String id, String status) async => _get(id).availability = status;

  @override
  Future<void> renew(String id) async => _get(id).expiresAt = DateTime.now().add(const Duration(days: 60));

  @override
  Future<void> delete(String id) async => _list.removeWhere((l) => l.id == id);

  @override
  Future<List<ViewingRequestItem>> viewingRequests() async => [];

  @override
  Future<void> decideViewing(String id, String status) async {}

  final _locations = <String, ExactLocation>{};

  @override
  Future<ExactLocation?> myLocation(String propertyId) async => _locations[propertyId];
  @override
  Future<void> saveLocation(String propertyId, double lat, double lng, String addressLine) async => _locations[propertyId] = ExactLocation(lat, lng, addressLine);
  @override
  Future<void> clearLocation(String propertyId) async => _locations.remove(propertyId);
}

class SupabaseLandlordRepository implements LandlordRepository {
  SupabaseClient get _c => Supabase.instance.client;
  String get _uid {
    final u = _c.auth.currentUser;
    if (u == null) throw const AuthException('Please sign in first.');
    return u.id;
  }

  static const _sel = 'id,title,description,area,rent_ngn,rent_period,room_type,distance_km,extra_fees_note,'
      'moderation_status,availability_status,verification_level,expires_at,views_count,moderation_note,university_id,$kExtrasColumns,'
      'universities:cs_universities(short_name),property_photos:cs_property_photos(id,storage_path,sort_order),property_amenities:cs_property_amenities(amenities:cs_amenities(code))';

  String _url(String path) => _c.storage.from('cs-property-photos').getPublicUrl(path);
  LandlordListing _l(Map<String, dynamic> m) => LandlordListing.fromMap(m, _url);

  @override
  Future<List<University>> universities() async {
    final rows = await _c.from('cs_universities').select('id,name,short_name,city,state,kind').order('name').limit(2000);
    return rows
        .map<University>((r) => University(r['id'] as String, r['name'] as String, r['short_name'] as String,
            city: (r['city'] ?? '') as String, state: (r['state'] ?? '') as String, kind: (r['kind'] ?? 'university') as String))
        .toList();
  }

  @override
  Future<DashboardStats> stats() async {
    final r = await _c.rpc('cs_landlord_stats') as Map;
    int n(String k) => (r[k] as num?)?.toInt() ?? 0;
    return DashboardStats(n('total'), n('active'), n('pending'), n('views'), n('enquiries'));
  }

  @override
  Future<List<LandlordListing>> myListings() async {
    final rows = await _c.from('cs_properties').select(_sel).eq('owner_id', _uid).order('created_at', ascending: false);
    return rows.map<LandlordListing>(_l).toList();
  }

  @override
  Future<LandlordListing> myListing(String id) async => _l(await _c.from('cs_properties').select(_sel).eq('id', id).single());

  Map<String, dynamic> _row(ListingInput i) => {
        'university_id': i.universityId,
        'title': i.title,
        'description': i.description,
        'area': i.area,
        'rent_ngn': i.rentNgn,
        'rent_period': i.rentPeriod,
        'room_type': i.roomType,
        'distance_km': i.distanceKm,
        'extra_fees_note': i.extraFees,
        ...i.extras.toMap(),
      };

  @override
  Future<String> saveDraft(String? id, ListingInput input) async {
    if (id == null) {
      final r = await _c.from('cs_properties').insert({..._row(input), 'owner_id': _uid}).select('id').single();
      return r['id'] as String;
    }
    await _c.from('cs_properties').update(_row(input)).eq('id', id);
    return id;
  }

  @override
  Future<PhotoRef> addPhoto(String propertyId, Uint8List bytes, String fileName, int sortOrder) async {
    final ext = _ext(fileName);
    final path = '$_uid/$propertyId/${_rid()}.$ext';
    await _c.storage.from('cs-property-photos').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: _mime(ext)));
    final row = await _c.from('cs_property_photos').insert({'property_id': propertyId, 'storage_path': path, 'sort_order': sortOrder}).select('id').single();
    return PhotoRef(row['id'] as String, path, _url(path));
  }

  @override
  Future<void> removePhoto(String propertyId, PhotoRef photo) async {
    await _c.from('cs_property_photos').delete().eq('id', photo.id);
    await _c.storage.from('cs-property-photos').remove([photo.path]);
  }

  @override
  Future<void> setAmenities(String propertyId, List<String> codes) async {
    await _c.from('cs_property_amenities').delete().eq('property_id', propertyId);
    if (codes.isEmpty) return;
    await _c.from('cs_property_amenities').insert([
      for (final c in codes)
        if (amenityIds[c] != null) {'property_id': propertyId, 'amenity_id': amenityIds[c]},
    ]);
  }

  @override
  Future<void> uploadVerificationDoc(String propertyId, String docType, Uint8List bytes, String fileName) async {
    final ext = _ext(fileName);
    final path = '$_uid/$propertyId/${_rid()}.$ext';
    await _c.storage.from('cs-verification-docs').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: _mime(ext)));
    await _c.from('cs_verification_submissions').insert({'user_id': _uid, 'property_id': propertyId, 'doc_type': docType, 'storage_path': path});
  }

  @override
  Future<void> submitForReview(String propertyId) async {
    final r = await _c.from('cs_properties').update({'moderation_status': 'pending'}).eq('id', propertyId).select('moderation_status').single();
    if (r['moderation_status'] != 'pending') throw const AppException(AppErrorKind.notSubmittable);
  }

  @override
  Future<void> setAvailability(String id, String status) async {
    await _c.from('cs_properties').update({'availability_status': status}).eq('id', id);
  }

  @override
  Future<void> renew(String id) async {
    await _c.rpc('cs_renew_listing', params: {'p_property_id': id});
  }

  @override
  Future<void> delete(String id) async {
    await _c.from('cs_properties').delete().eq('id', id);
  }

  @override
  Future<List<ViewingRequestItem>> viewingRequests() async {
    final rows = await _c
        .from('cs_viewing_requests')
        .select('id,preferred_at,note,status,properties:cs_properties(title)')
        .order('preferred_at', ascending: false)
        .limit(100);
    return rows.map<ViewingRequestItem>((r) {
      final p = r['properties'];
      return ViewingRequestItem(
        r['id'] as String,
        p is Map ? p['title'] as String : 'Listing',
        DateTime.parse(r['preferred_at'] as String).toLocal(),
        r['note'] as String?,
        r['status'] as String,
      );
    }).toList();
  }

  @override
  Future<void> decideViewing(String id, String status) async {
    await _c.from('cs_viewing_requests').update({'status': status}).eq('id', id);
  }

  @override
  Future<ExactLocation?> myLocation(String propertyId) async {
    final r = await _c.from('cs_property_locations').select('lat,lng,address_line').eq('property_id', propertyId).maybeSingle();
    if (r == null) return null;
    return ExactLocation((r['lat'] as num).toDouble(), (r['lng'] as num).toDouble(), (r['address_line'] ?? '') as String);
  }

  @override
  Future<void> saveLocation(String propertyId, double lat, double lng, String addressLine) async {
    await _c.from('cs_property_locations').upsert({
      'property_id': propertyId,
      'lat': lat,
      'lng': lng,
      'address_line': addressLine.isEmpty ? null : addressLine,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<void> clearLocation(String propertyId) async {
    await _c.from('cs_property_locations').delete().eq('property_id', propertyId);
  }
}

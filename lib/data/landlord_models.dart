import 'models.dart';

class University {
  final String id, name, shortName;
  const University(this.id, this.name, this.shortName);
}

class PhotoRef {
  final String id, path;
  final String? url;
  const PhotoRef(this.id, this.path, this.url);
}

class ListingInput {
  final String title, description, area, rentPeriod, roomType, universityId;
  final int rentNgn;
  final double? distanceKm;
  final String? extraFees;
  const ListingInput({
    required this.title,
    required this.description,
    required this.area,
    required this.rentPeriod,
    required this.roomType,
    required this.universityId,
    required this.rentNgn,
    this.distanceKm,
    this.extraFees,
  });
}

const amenityIds = {'wifi': 1, 'water': 2, 'electricity': 3, 'parking': 4, 'cctv': 5, 'kitchen': 6, 'laundry': 7, 'ac': 8};

class LandlordListing {
  String id, title, description, area, university, rentPeriod, roomType, moderation, availability, verification;
  String? universityId, extraFees, moderationNote, ownerId;
  int rentNgn, views;
  double? distanceKm;
  DateTime? expiresAt;
  List<PhotoRef> photos;
  List<String> amenities;

  LandlordListing({
    required this.id,
    required this.title,
    required this.description,
    required this.area,
    required this.university,
    required this.rentPeriod,
    required this.roomType,
    required this.moderation,
    required this.availability,
    required this.verification,
    required this.rentNgn,
    this.universityId,
    this.extraFees,
    this.moderationNote,
    this.ownerId,
    this.views = 0,
    this.distanceKm,
    this.expiresAt,
    this.photos = const [],
    this.amenities = const [],
  });

  factory LandlordListing.fromMap(Map<String, dynamic> m, String Function(String) photoUrl) {
    final photos = ((m['property_photos'] as List?) ?? []).cast<Map<String, dynamic>>().toList()
      ..sort((a, b) => ((a['sort_order'] ?? 0) as int).compareTo((b['sort_order'] ?? 0) as int));
    final uni = m['universities'];
    return LandlordListing(
      id: m['id'] as String,
      title: m['title'] as String,
      description: (m['description'] ?? '') as String,
      area: (m['area'] ?? '') as String,
      university: uni is Map ? (uni['short_name'] ?? '') as String : '',
      universityId: m['university_id'] as String?,
      rentNgn: (m['rent_ngn'] as num).toInt(),
      rentPeriod: (m['rent_period'] ?? 'year') as String,
      roomType: m['room_type'] as String,
      distanceKm: (m['distance_km'] as num?)?.toDouble(),
      extraFees: m['extra_fees_note'] as String?,
      moderation: m['moderation_status'] as String,
      availability: m['availability_status'] as String,
      verification: (m['verification_level'] ?? 'unverified') as String,
      expiresAt: m['expires_at'] == null ? null : DateTime.parse(m['expires_at'] as String).toLocal(),
      views: (m['views_count'] as num?)?.toInt() ?? 0,
      moderationNote: m['moderation_note'] as String?,
      ownerId: m['owner_id'] as String?,
      photos: photos.map((p) => PhotoRef(p['id'] as String, p['storage_path'] as String, photoUrl(p['storage_path'] as String))).toList(),
      amenities: ((m['property_amenities'] as List?) ?? [])
          .map((e) => (e as Map)['amenities'])
          .whereType<Map>()
          .map((a) => a['code'] as String)
          .toList(),
    );
  }

  bool get isExpired => moderation == 'approved' && expiresAt != null && expiresAt!.isBefore(DateTime.now());
  bool get isActive => moderation == 'approved' && availability == 'available' && !isExpired;
  int? get daysLeft => expiresAt?.difference(DateTime.now()).inDays;
  bool get needsReconfirm => moderation == 'approved' && availability == 'available' && (isExpired || (daysLeft ?? 99) <= 7);

  /// active | review | inactive
  String get bucket => isActive ? 'active' : (moderation == 'approved' ? 'inactive' : 'review');

  String get statusLabel {
    if (isActive) return 'Live';
    if (isExpired) return 'Expired';
    switch (moderation) {
      case 'approved':
        return availability == 'rented' ? 'Rented' : 'Paused';
      case 'pending':
        return 'Pending review';
      case 'needs_changes':
        return 'Changes needed';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Draft';
    }
  }

  String get rentLabel => '₦${formatNaira(rentNgn)}/${rentPeriod == 'month' ? 'month' : 'year'}';
  String get roomTypeLabel => roomTypeLabels[roomType] ?? roomType;
}

class DashboardStats {
  final int total, active, pending, views, enquiries;
  const DashboardStats(this.total, this.active, this.pending, this.views, this.enquiries);
}

class ViewingRequestItem {
  final String id, propertyTitle, status;
  final DateTime preferredAt;
  final String? note;
  const ViewingRequestItem(this.id, this.propertyTitle, this.preferredAt, this.note, this.status);
}

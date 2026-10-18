import 'amenity_catalog.dart';
import 'property_extras.dart';

export 'amenity_catalog.dart';
export 'property_extras.dart';

class Property {
  final String id;
  final String title;
  final String description;
  final String area;
  final String university;
  final int rentNgn;
  final String rentPeriod; // month | year
  final String roomType;
  final double? distanceKm;
  final String verification; // unverified | pending | verified
  final List<String> amenities;
  final List<String> photoUrls;
  final String? extraFeesNote;
  final PropertyExtras extras;
  final double? approxLat, approxLng;

  const Property({
    required this.id,
    required this.title,
    required this.description,
    required this.area,
    required this.university,
    required this.rentNgn,
    required this.rentPeriod,
    required this.roomType,
    this.distanceKm,
    this.verification = 'unverified',
    this.amenities = const [],
    this.photoUrls = const [],
    this.extraFeesNote,
    this.extras = const PropertyExtras(),
    this.approxLat,
    this.approxLng,
  });

  /// [photoBase] turns a storage path into a public URL.
  factory Property.fromMap(Map<String, dynamic> m, String Function(String) photoBase) {
    final photos = ((m['property_photos'] as List?) ?? [])
        .cast<Map<String, dynamic>>()
        .toList()
      ..sort((a, b) => ((a['sort_order'] ?? 0) as int).compareTo((b['sort_order'] ?? 0) as int));
    final ams = ((m['property_amenities'] as List?) ?? [])
        .map((e) => (e as Map)['amenities'])
        .whereType<Map>()
        .map((a) => a['code'] as String)
        .toList();
    final uni = m['universities'];
    return Property(
      id: m['id'] as String,
      title: m['title'] as String,
      description: (m['description'] ?? '') as String,
      area: (m['area'] ?? '') as String,
      university: uni is Map ? (uni['short_name'] ?? '') as String : '',
      rentNgn: (m['rent_ngn'] as num).toInt(),
      rentPeriod: (m['rent_period'] ?? 'year') as String,
      roomType: m['room_type'] as String,
      distanceKm: (m['distance_km'] as num?)?.toDouble(),
      verification: (m['verification_level'] ?? 'unverified') as String,
      amenities: ams,
      photoUrls: photos.map((p) => photoBase(p['storage_path'] as String)).toList(),
      extraFeesNote: m['extra_fees_note'] as String?,
      extras: PropertyExtras.fromMap(m),
      approxLat: (m['approx_lat'] as num?)?.toDouble(),
      approxLng: (m['approx_lng'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'area': area,
        'university': university,
        'rentNgn': rentNgn,
        'rentPeriod': rentPeriod,
        'roomType': roomType,
        'distanceKm': distanceKm,
        'verification': verification,
        'amenities': amenities,
        'photoUrls': photoUrls,
        'extraFeesNote': extraFeesNote,
        'extras': extras.toMap(),
        'approxLat': approxLat,
        'approxLng': approxLng,
      };

  factory Property.fromJson(Map<String, dynamic> j) => Property(
        id: j['id'] as String,
        title: j['title'] as String,
        description: (j['description'] ?? '') as String,
        area: (j['area'] ?? '') as String,
        university: (j['university'] ?? '') as String,
        rentNgn: (j['rentNgn'] as num).toInt(),
        rentPeriod: (j['rentPeriod'] ?? 'year') as String,
        roomType: j['roomType'] as String,
        distanceKm: (j['distanceKm'] as num?)?.toDouble(),
        verification: (j['verification'] ?? 'unverified') as String,
        amenities: ((j['amenities'] as List?) ?? const []).cast<String>(),
        photoUrls: ((j['photoUrls'] as List?) ?? const []).cast<String>(),
        extraFeesNote: j['extraFeesNote'] as String?,
        extras: PropertyExtras.fromMap(Map<String, dynamic>.from((j['extras'] as Map?) ?? const {})),
        approxLat: (j['approxLat'] as num?)?.toDouble(),
        approxLng: (j['approxLng'] as num?)?.toDouble(),
      );

  String get rentLabel => '₦${formatNaira(rentNgn)}/${rentPeriod == 'month' ? 'month' : 'year'}';
  String get roomTypeLabel => roomTypeLabels[roomType] ?? roomType;
  String get school => university.isNotEmpty ? university : extras.schoolOther;
  String get locationLabel {
    if (school.isEmpty) return area;
    if (distanceKm != null) return '$area, ${distanceKm!.toStringAsFixed(1)} km from $school';
    if (extras.walkMinutes != null) return '$area, ${extras.walkMinutes} min walk from $school';
    return '$area, $school';
  }
}

const roomTypeLabels = {
  'single_room': 'Single Room',
  'shared_room': 'Shared Room',
  'self_contain': 'Self-contain',
  'apartment': 'Apartment',
  'hostel': 'Hostel',
};

String formatNaira(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

class SearchFilter {
  final String query;
  final int? minRent;
  final int? maxRent;
  final String? roomType;
  final String? universityId;
  final String? schoolName;
  final String? furnishing;
  final String? forGender; // male | female: matches listings open to that gender
  final int? minBedrooms;
  final int? maxWalk; // minutes on foot
  final Set<String> amenities;
  const SearchFilter({
    this.query = '',
    this.minRent,
    this.maxRent,
    this.roomType,
    this.universityId,
    this.schoolName,
    this.furnishing,
    this.forGender,
    this.minBedrooms,
    this.maxWalk,
    this.amenities = const {},
  });

  SearchFilter copyWith({String? query}) => SearchFilter(
        query: query ?? this.query,
        minRent: minRent,
        maxRent: maxRent,
        roomType: roomType,
        universityId: universityId,
        schoolName: schoolName,
        furnishing: furnishing,
        forGender: forGender,
        minBedrooms: minBedrooms,
        maxWalk: maxWalk,
        amenities: amenities,
      );

  Map<String, dynamic> toJson() => {
        'query': query,
        if (minRent != null) 'minRent': minRent,
        if (maxRent != null) 'maxRent': maxRent,
        if (roomType != null) 'roomType': roomType,
        if (universityId != null) 'universityId': universityId,
        if (schoolName != null) 'schoolName': schoolName,
        if (furnishing != null) 'furnishing': furnishing,
        if (forGender != null) 'forGender': forGender,
        if (minBedrooms != null) 'minBedrooms': minBedrooms,
        if (maxWalk != null) 'maxWalk': maxWalk,
        'amenities': amenities.toList(),
      };

  factory SearchFilter.fromJson(Map<String, dynamic> j) => SearchFilter(
        query: (j['query'] ?? '') as String,
        minRent: (j['minRent'] as num?)?.toInt(),
        maxRent: (j['maxRent'] as num?)?.toInt(),
        roomType: j['roomType'] as String?,
        universityId: j['universityId'] as String?,
        schoolName: j['schoolName'] as String?,
        furnishing: j['furnishing'] as String?,
        forGender: j['forGender'] as String?,
        minBedrooms: (j['minBedrooms'] as num?)?.toInt(),
        maxWalk: (j['maxWalk'] as num?)?.toInt(),
        amenities: {...((j['amenities'] as List?) ?? const []).cast<String>()},
      );

  int get activeCount =>
      [minRent != null || maxRent != null, roomType != null, universityId != null, furnishing != null, forGender != null, minBedrooms != null, maxWalk != null, amenities.isNotEmpty]
          .where((b) => b)
          .length;
  bool get isActive => activeCount > 0;
}

class ReviewSummary {
  final double average;
  final int count;
  const ReviewSummary(this.average, this.count);
}

class Review {
  final String id, comment, reply;
  final int rating;
  final DateTime createdAt;
  final DateTime? repliedAt;
  final bool mine;
  const Review(this.id, this.rating, this.comment, this.createdAt, this.mine, this.reply, this.repliedAt);
}

class SavedSearch {
  final String id, name;
  final SearchFilter filter;
  final DateTime lastSeenAt;
  const SavedSearch(this.id, this.name, this.filter, this.lastSeenAt);
}

class Conversation {
  final String id;
  final String title;
  final String? otherUserId;
  const Conversation(this.id, this.title, [this.otherUserId]);
}

class ChatMessage {
  final String id;
  final String body;
  final bool mine;
  final DateTime at;
  const ChatMessage(this.id, this.body, this.mine, this.at);
}

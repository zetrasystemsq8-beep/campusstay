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
    );
  }

  String get rentLabel => '₦${formatNaira(rentNgn)}/${rentPeriod == 'month' ? 'month' : 'year'}';
  String get roomTypeLabel => roomTypeLabels[roomType] ?? roomType;
  String get locationLabel =>
      distanceKm == null ? '$area, $university' : '$area, ${distanceKm!.toStringAsFixed(1)} km from $university';
}

const roomTypeLabels = {
  'single_room': 'Single Room',
  'shared_room': 'Shared Room',
  'self_contain': 'Self-contain',
  'apartment': 'Apartment',
  'hostel': 'Hostel',
};

const amenityLabels = {
  'wifi': 'WiFi',
  'water': 'Water',
  'electricity': 'Electricity',
  'parking': 'Parking',
  'cctv': 'CCTV',
  'kitchen': 'Kitchen',
  'laundry': 'Laundry',
  'ac': 'AC',
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
  const SearchFilter({this.query = '', this.minRent, this.maxRent, this.roomType});

  SearchFilter copyWith({String? query, int? minRent, int? maxRent, String? roomType, bool clearRoom = false, bool clearRent = false}) =>
      SearchFilter(
        query: query ?? this.query,
        minRent: clearRent ? null : (minRent ?? this.minRent),
        maxRent: clearRent ? null : (maxRent ?? this.maxRent),
        roomType: clearRoom ? null : (roomType ?? this.roomType),
      );

  bool get isActive => minRent != null || maxRent != null || roomType != null;
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

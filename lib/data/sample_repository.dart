import '../core/errors.dart';
import 'location_models.dart';
import 'models.dart';
import 'repository.dart';

/// Development-mode data. These are fictional sample listings, not real
/// properties, and none are marked verified.
class SampleRepository implements Repository {
  final _favs = <String>{};
  final _searches = <SavedSearch>[];
  final _convs = <Conversation>[];
  final _msgs = <String, List<ChatMessage>>{};

  static const _all = <Property>[
    Property(id: 's1', title: 'Sample single room', description: 'Fictional sample listing for development. Quiet street, close to the campus gate.', area: 'Ado-Ekiti', university: 'EKSU', rentNgn: 150000, rentPeriod: 'year', roomType: 'single_room', distanceKm: 1.2, amenities: ['water', 'electricity', 'parking'], approxLat: 7.6225, approxLng: 5.2210),
    Property(id: 's2', title: 'Sample self-contain', description: 'Fictional sample listing for development.', area: 'Oye-Ekiti', university: 'FUOYE', rentNgn: 220000, rentPeriod: 'year', roomType: 'self_contain', distanceKm: 0.8, amenities: ['wifi', 'water', 'electricity', 'cctv'], extras: PropertyExtras(bedrooms: 1, furnishing: 'furnished', genderPreference: 'female_only', landmark: 'Opposite the main gate', cautionFeeNgn: 20000, allowsInstalments: true, maxOccupants: 2, houseRules: 'No loud music after 10pm.', walkMinutes: 10, bikeFareNgn: 300, kekeFareNgn: 200, electricityBilling: 'prepaid', waterBilling: 'included'), approxLat: 7.7990, approxLng: 5.3170),
    Property(id: 's3', title: 'Sample shared room', description: 'Fictional sample listing for development.', area: 'Ado-Ekiti', university: 'EKSU', rentNgn: 70000, rentPeriod: 'year', roomType: 'shared_room', distanceKm: 2.5, amenities: ['water', 'laundry']),
    Property(id: 's4', title: 'Sample 2-bedroom flat', description: 'Fictional sample listing for development.', area: 'Ado-Ekiti', university: 'EKSU', rentNgn: 450000, rentPeriod: 'year', roomType: 'apartment', distanceKm: 3.1, amenities: ['water', 'electricity', 'parking', 'kitchen', 'ac']),
    Property(id: 's5', title: 'Sample hostel bed space', description: 'Fictional sample listing for development.', area: 'Oye-Ekiti', university: 'FUOYE', rentNgn: 45000, rentPeriod: 'year', roomType: 'hostel', distanceKm: 0.4, amenities: ['water', 'cctv', 'laundry']),
  ];

  bool _matches(Property p, SearchFilter f) {
    final q = f.query.toLowerCase();
    if (q.isNotEmpty && !('${p.title} ${p.area} ${p.university}'.toLowerCase().contains(q))) return false;
    if (f.minRent != null && p.rentNgn < f.minRent!) return false;
    if (f.maxRent != null && p.rentNgn > f.maxRent!) return false;
    if (f.roomType != null && p.roomType != f.roomType) return false;
    if (f.universityId != null && p.university != f.schoolName) return false;
    if (f.furnishing != null && p.extras.furnishing != f.furnishing) return false;
    if (f.minBedrooms != null && p.extras.bedrooms < f.minBedrooms!) return false;
    if (f.maxWalk != null && (p.extras.walkMinutes == null || p.extras.walkMinutes! > f.maxWalk!)) return false;
    if (f.forGender != null && p.extras.genderPreference != 'any' && p.extras.genderPreference != '${f.forGender}_only') return false;
    if (f.amenities.isNotEmpty && !f.amenities.every(p.amenities.contains)) return false;
    return true;
  }

  @override
  Future<List<Property>> search(SearchFilter f, {int page = 0}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final r = _all.where((p) => _matches(p, f)).toList();
    final start = page * Repository.pageSize;
    if (start >= r.length) return [];
    return r.sublist(start, (start + Repository.pageSize).clamp(0, r.length));
  }

  @override
  Future<List<Property>> mapListings(SearchFilter f, {required double south, required double west, required double north, required double east}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _all
        .where((p) => _matches(p, f) && p.approxLat != null && p.approxLng != null && p.approxLat! >= south && p.approxLat! <= north && p.approxLng! >= west && p.approxLng! <= east)
        .toList();
  }

  @override
  Future<ExactLocation?> exactLocation(String propertyId) async => null;

  @override
  Future<String> contactStatus(String propertyId) async => ContactStatus.hidden;

  @override
  Future<String> replySpeed(String propertyId) async => 'unknown';

  @override
  Future<ReviewSummary> reviewSummary(String propertyId) async => const ReviewSummary(0, 0);

  @override
  Future<List<Review>> reviews(String propertyId) async => [];

  @override
  Future<String> canReview(String propertyId) async => 'no';

  @override
  Future<void> submitReview(String propertyId, int rating, String comment) async =>
      throw const AppException(AppErrorKind.forbidden);

  @override
  Future<List<SavedSearch>> savedSearches() async => [..._searches];

  @override
  Future<void> saveSearch(String name, SearchFilter f) async => _searches.add(SavedSearch('s${_searches.length + 1}', name, f, DateTime.now()));

  @override
  Future<void> deleteSavedSearch(String id) async => _searches.removeWhere((s) => s.id == id);

  @override
  Future<int> countNewMatches(SavedSearch s) async => 0;

  @override
  Future<void> markSearchSeen(String id) async {}

  @override
  Future<String> revealPhone(String propertyId) async =>
      throw const AppException(AppErrorKind.forbidden);

  @override
  Future<Property> property(String id) async => _all.firstWhere((p) => p.id == id);

  @override
  Future<Set<String>> favouriteIds() async => {..._favs};

  @override
  Future<List<Property>> favourites() async => _all.where((p) => _favs.contains(p.id)).toList();

  @override
  Future<void> setFavourite(String propertyId, bool on) async => on ? _favs.add(propertyId) : _favs.remove(propertyId);

  @override
  Future<void> requestViewing(String propertyId, DateTime preferred, String note) async {}

  @override
  Future<void> sendEnquiry(String propertyId, String message) async {
    final p = _all.firstWhere((e) => e.id == propertyId);
    final id = 'c${_convs.length + 1}';
    _convs.add(Conversation(id, p.title));
    _msgs[id] = [ChatMessage('m1', message, true, DateTime.now())];
  }

  @override
  Future<List<Conversation>> conversations() async => [..._convs];

  @override
  Future<List<ChatMessage>> messages(String conversationId) async => [...?_msgs[conversationId]];

  @override
  Future<void> sendMessage(String conversationId, String body) async =>
      _msgs[conversationId]!.add(ChatMessage('m${_msgs[conversationId]!.length + 1}', body, true, DateTime.now()));

  @override
  Future<void> blockUser(String userId) async {}

  @override
  Future<void> report(String targetType, String targetId, String reason, String details) async {}
}

import 'models.dart';
import 'repository.dart';

/// Development-mode data. These are fictional sample listings, not real
/// properties, and none are marked verified.
class SampleRepository implements Repository {
  final _favs = <String>{};
  final _convs = <Conversation>[];
  final _msgs = <String, List<ChatMessage>>{};

  static const _all = <Property>[
    Property(id: 's1', title: 'Sample single room', description: 'Fictional sample listing for development. Quiet street, close to the campus gate.', area: 'Ado-Ekiti', university: 'EKSU', rentNgn: 150000, rentPeriod: 'year', roomType: 'single_room', distanceKm: 1.2, amenities: ['water', 'electricity', 'parking']),
    Property(id: 's2', title: 'Sample self-contain', description: 'Fictional sample listing for development.', area: 'Oye-Ekiti', university: 'FUOYE', rentNgn: 220000, rentPeriod: 'year', roomType: 'self_contain', distanceKm: 0.8, amenities: ['wifi', 'water', 'electricity', 'cctv']),
    Property(id: 's3', title: 'Sample shared room', description: 'Fictional sample listing for development.', area: 'Ado-Ekiti', university: 'EKSU', rentNgn: 70000, rentPeriod: 'year', roomType: 'shared_room', distanceKm: 2.5, amenities: ['water', 'laundry']),
    Property(id: 's4', title: 'Sample 2-bedroom flat', description: 'Fictional sample listing for development.', area: 'Ado-Ekiti', university: 'EKSU', rentNgn: 450000, rentPeriod: 'year', roomType: 'apartment', distanceKm: 3.1, amenities: ['water', 'electricity', 'parking', 'kitchen', 'ac']),
    Property(id: 's5', title: 'Sample hostel bed space', description: 'Fictional sample listing for development.', area: 'Oye-Ekiti', university: 'FUOYE', rentNgn: 45000, rentPeriod: 'year', roomType: 'hostel', distanceKm: 0.4, amenities: ['water', 'cctv', 'laundry']),
  ];

  @override
  Future<List<Property>> search(SearchFilter f, {int page = 0}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final q = f.query.toLowerCase();
    final r = _all.where((p) {
      if (q.isNotEmpty && !('${p.title} ${p.area} ${p.university}'.toLowerCase().contains(q))) return false;
      if (f.minRent != null && p.rentNgn < f.minRent!) return false;
      if (f.maxRent != null && p.rentNgn > f.maxRent!) return false;
      if (f.roomType != null && p.roomType != f.roomType) return false;
      return true;
    }).toList();
    final start = page * Repository.pageSize;
    if (start >= r.length) return [];
    return r.sublist(start, (start + Repository.pageSize).clamp(0, r.length));
  }

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
  Future<void> report(String targetType, String targetId, String reason, String details) async {}
}

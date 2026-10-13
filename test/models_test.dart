import 'package:flutter_test/flutter_test.dart';
import 'package:campusstay/data/models.dart';
import 'package:campusstay/data/sample_repository.dart';

void main() {
  test('formatNaira groups thousands', () {
    expect(formatNaira(50000), '50,000');
    expect(formatNaira(1234567), '1,234,567');
    expect(formatNaira(999), '999');
  });

  test('Property.fromMap parses nested rows and sorts photos', () {
    final p = Property.fromMap({
      'id': 'a', 'title': 'Room', 'area': 'Ado', 'rent_ngn': 100000, 'rent_period': 'year',
      'room_type': 'single_room', 'verification_level': 'unverified',
      'universities': {'short_name': 'EKSU'},
      'property_photos': [
        {'storage_path': 'b.jpg', 'sort_order': 2},
        {'storage_path': 'a.jpg', 'sort_order': 1},
      ],
      'property_amenities': [{'amenities': {'code': 'wifi'}}],
    }, (path) => 'https://x/$path');
    expect(p.photoUrls, ['https://x/a.jpg', 'https://x/b.jpg']);
    expect(p.amenities, ['wifi']);
    expect(p.rentLabel, '₦100,000/year');
  });

  test('sample repository filters by rent and room type', () async {
    final r = SampleRepository();
    final cheap = await r.search(const SearchFilter(maxRent: 100000));
    expect(cheap.every((p) => p.rentNgn <= 100000), true);
    final hostels = await r.search(const SearchFilter(roomType: 'hostel'));
    expect(hostels.every((p) => p.roomType == 'hostel'), true);
  });

  test('favourites toggle in sample repository', () async {
    final r = SampleRepository();
    await r.setFavourite('s1', true);
    expect((await r.favouriteIds()).contains('s1'), true);
    await r.setFavourite('s1', false);
    expect((await r.favouriteIds()).isEmpty, true);
  });
}

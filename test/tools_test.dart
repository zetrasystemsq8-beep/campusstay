import 'package:flutter_test/flutter_test.dart';
import 'package:campusstay/core/safety.dart';
import 'package:campusstay/core/share.dart';
import 'package:campusstay/data/models.dart';
import 'package:campusstay/data/repository.dart';
import 'package:campusstay/features/explore/compare_screen.dart';

void main() {
  test('scam patterns are flagged, normal chat is not', () {
    expect(SafetyCheck.scan('Please transfer the money first before you come'), contains(SafetyFlag.money));
    expect(SafetyCheck.scan('Send your OTP so I can confirm'), contains(SafetyFlag.secretCode));
    expect(SafetyCheck.scan('Pay to this account 0123456789'), contains(SafetyFlag.account));
    expect(SafetyCheck.scan('Call me on 08012345678'), contains(SafetyFlag.phone));
    expect(SafetyCheck.scan('Is the room still available? Can I see it on Saturday?'), isEmpty);
  });

  test('search filters survive being saved and loaded', () {
    const f = SearchFilter(query: 'self', maxRent: 200000, roomType: 'self_contain', universityId: 'u1', schoolName: 'EKSU', furnishing: 'furnished', forGender: 'female', minBedrooms: 2, maxWalk: 10, amenities: {'wifi', 'water'});
    final back = SearchFilter.fromJson(f.toJson());
    expect(back.query, 'self');
    expect(back.maxRent, 200000);
    expect(back.roomType, 'self_contain');
    expect(back.schoolName, 'EKSU');
    expect(back.forGender, 'female');
    expect(back.minBedrooms, 2);
    expect(back.maxWalk, 10);
    expect(back.amenities, {'wifi', 'water'});
    expect(back.activeCount, f.activeCount);
  });

  test('comparison uses yearly rent and the full first payment', () {
    const monthly = Property(id: 'a', title: 'A', description: '', area: 'x', university: 'U', rentNgn: 20000, rentPeriod: 'month', roomType: 'single_room');
    const yearly = Property(id: 'b', title: 'B', description: '', area: 'x', university: 'U', rentNgn: 200000, rentPeriod: 'year', roomType: 'single_room', extras: PropertyExtras(cautionFeeNgn: 20000, serviceChargeNgn: 5000));
    expect(annualRent(monthly), 240000);
    expect(annualRent(yearly), 200000);
    expect(firstPayment(yearly), 225000);
  });

  test('shared text never includes an exact address or phone', () {
    const p = Property(id: 'a', title: 'Self-contain near EKSU', description: '', area: 'Ado-Ekiti', university: 'EKSU', rentNgn: 150000, rentPeriod: 'year', roomType: 'self_contain', extras: PropertyExtras(landmark: 'Opposite the main gate'));
    final t = listingShareText(p);
    expect(t, contains('Self-contain near EKSU'));
    expect(t, contains('₦150,000/year'));
    expect(t.contains('Opposite the main gate'), false);
  });

  test('saved searches are stored and removed (sample mode)', () async {
    final r = Services.repo;
    await r.saveSearch('Cheap rooms', const SearchFilter(maxRent: 100000));
    final list = await r.savedSearches();
    expect(list.any((s) => s.name == 'Cheap rooms'), true);
    await r.deleteSavedSearch(list.firstWhere((s) => s.name == 'Cheap rooms').id);
    expect((await r.savedSearches()).any((s) => s.name == 'Cheap rooms'), false);
  });
}

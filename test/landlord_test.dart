import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:campusstay/data/landlord_models.dart';
import 'package:campusstay/data/models.dart';
import 'package:campusstay/data/landlord_repository.dart';

ListingInput _input(String title) => ListingInput(
      title: title,
      description: 'A fictional test description for the listing.',
      area: 'Ado-Ekiti',
      rentPeriod: 'year',
      roomType: 'single_room',
      universityId: 'u1',
      rentNgn: 150000,
    );

void main() {
  test('transport and bills survive the database round trip', () {
    const e = PropertyExtras(walkMinutes: 10, bikeFareNgn: 300, kekeFareNgn: 200, busFareNgn: 150, electricityBilling: 'prepaid', waterBilling: 'included');
    final back = PropertyExtras.fromMap(e.toMap());
    expect(back.walkMinutes, 10);
    expect(back.bikeFareNgn, 300);
    expect(back.kekeFareNgn, 200);
    expect(back.busFareNgn, 150);
    expect(back.electricityBilling, 'prepaid');
    expect(back.waterBilling, 'included');
  });

  test('walking time is used when there is no distance in km', () {
    const p = Property(id: '1', title: 'Room', description: '', area: 'Ado-Ekiti', university: 'EKSU', rentNgn: 1, rentPeriod: 'year', roomType: 'single_room', extras: PropertyExtras(walkMinutes: 10));
    expect(p.locationLabel, 'Ado-Ekiti, 10 min walk from EKSU');
  });

  test('amenity catalog ids are unique and match labels', () {
    final ids = amenityCatalog.map((a) => a.id).toSet();
    final codes = amenityCatalog.map((a) => a.code).toSet();
    expect(ids.length, amenityCatalog.length);
    expect(codes.length, amenityCatalog.length);
    expect(amenityIds['borehole'], 9);
    expect(amenityLabels['wifi'], 'WiFi');
  });

  test('PropertyExtras round-trips through the database shape', () {
    final e = PropertyExtras(bedrooms: 2, furnishing: 'furnished', genderPreference: 'female_only', cautionFeeNgn: 20000, availableFrom: DateTime(2026, 11, 5), houseRules: 'No loud music');
    final back = PropertyExtras.fromMap(e.toMap());
    expect(back.bedrooms, 2);
    expect(back.furnishing, 'furnished');
    expect(back.genderPreference, 'female_only');
    expect(back.cautionFeeNgn, 20000);
    expect(back.availableFrom, DateTime(2026, 11, 5));
    expect(back.houseRules, 'No loud music');
    expect(const PropertyExtras().toMap()['landmark'], isNull);
  });

  test('search filter counts active filters', () {
    expect(const SearchFilter().activeCount, 0);
    expect(const SearchFilter(maxRent: 100000, minBedrooms: 2, amenities: {'wifi'}).activeCount, 3);
  });

  test('listing status buckets', () {
    LandlordListing mk(String mod, String av, {DateTime? exp}) => LandlordListing(
        id: 'x', title: 't', description: '', area: 'a', university: 'U', rentPeriod: 'year', roomType: 'single_room',
        moderation: mod, availability: av, verification: 'unverified', rentNgn: 1, expiresAt: exp);
    expect(mk('approved', 'available', exp: DateTime.now().add(const Duration(days: 30))).bucket, 'active');
    expect(mk('approved', 'available', exp: DateTime.now().subtract(const Duration(days: 1))).bucket, 'inactive');
    expect(mk('approved', 'rented').bucket, 'inactive');
    expect(mk('pending', 'available').bucket, 'review');
    expect(mk('rejected', 'available').statusLabel, 'Rejected');
    expect(mk('approved', 'available', exp: DateTime.now().add(const Duration(days: 3))).needsReconfirm, true);
  });

  test('sample landlord repo: draft, submit, pause, delete', () async {
    final r = SampleLandlordRepository();
    final id = await r.saveDraft(null, _input('Test room one'));
    expect((await r.myListing(id)).moderation, 'draft');
    await r.addPhoto(id, Uint8List(3), 'a.jpg', 0);
    await r.setAmenities(id, ['wifi', 'water']);
    await r.submitForReview(id);
    expect((await r.stats()).pending, 1);
    await r.setAvailability(id, 'paused');
    expect((await r.myListing(id)).availability, 'paused');
    await r.delete(id);
    expect(await r.myListings(), isEmpty);
  });
}

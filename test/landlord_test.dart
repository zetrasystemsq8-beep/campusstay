import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:campusstay/data/landlord_models.dart';
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

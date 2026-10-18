import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:campusstay/core/errors.dart';
import 'package:campusstay/data/models.dart';
import 'package:campusstay/features/legal/legal_screens.dart';

void main() {
  test('a listing survives being saved to the offline copy and read back', () {
    const p = Property(
      id: 'p1', title: 'Self-contain near EKSU', description: 'Nice place for students.', area: 'Ado-Ekiti', university: 'EKSU',
      rentNgn: 180000, rentPeriod: 'year', roomType: 'self_contain', distanceKm: null, verification: 'verified',
      amenities: ['wifi', 'water'], photoUrls: ['https://x/a.jpg'], extraFeesNote: 'Agreement fee 10000',
      extras: PropertyExtras(bedrooms: 2, furnishing: 'furnished', walkMinutes: 10, bikeFareNgn: 300, spacesAvailable: 3),
      approxLat: 7.62, approxLng: 5.22,
    );
    final back = Property.fromJson(p.toJson());
    expect(back.id, 'p1');
    expect(back.rentLabel, p.rentLabel);
    expect(back.amenities, ['wifi', 'water']);
    expect(back.photoUrls, ['https://x/a.jpg']);
    expect(back.extras.bedrooms, 2);
    expect(back.extras.walkMinutes, 10);
    expect(back.extras.spacesAvailable, 3);
    expect(back.approxLat, 7.62);
    expect(back.locationLabel, 'Ado-Ekiti, 10 min walk from EKSU');
  });

  test('a wrong or expired reset code gets its own message', () {
    expect(classify(const AuthException('Token has expired or is invalid')).kind, AppErrorKind.codeInvalid);
    expect(describe(const AppException(AppErrorKind.codeInvalid)).title, "That code didn't work");
  });

  test('review errors are explained, not generic', () {
    final e = classify(const PostgrestException(message: 'invalid rating', code: 'P0001'));
    expect(e.kind, AppErrorKind.invalid);
    expect(describe(e).message, 'Choose 1 to 5 stars.');
    expect(classify(const PostgrestException(message: 'not allowed', code: 'P0001')).kind, AppErrorKind.forbidden);
  });

  test('terms have a version to record at sign-up', () {
    expect(kTermsVersion.isNotEmpty, true);
  });
}

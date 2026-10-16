import 'package:flutter_test/flutter_test.dart';
import 'package:campusstay/data/profile_models.dart';
import 'package:campusstay/data/profile_repository.dart';

void main() {
  test('phone validation matches the database rule', () {
    expect(isValidPhone('08012345678'), true);
    expect(isValidPhone('+234 801 234 5678'), true);
    expect(isValidPhone('0801-234'), false);
    expect(isValidPhone('abc'), false);
    expect(isValidPhone('123'), false);
  });

  test('initials and role labels come from real data', () {
    const p = ProfileData(id: '1', email: 'amy@example.com', role: 'landlord', fullName: 'Ada Obi');
    expect(p.initials, 'AO');
    expect(p.roleLabel, 'Landlord');
    const q = ProfileData(id: '2', email: 'zed@example.com', role: 'admin');
    expect(q.initials, 'Z');
    expect(q.name, '');
    expect(q.roleLabel, 'Administrator');
  });

  test('sample repository saves name and phone', () async {
    final r = SampleProfileRepository();
    await r.save('Ada Obi', '08012345678', 'after_enquiry');
    // AuthService.role() is demo-only, so just check the stored values via save/load pair
    expect((await r.load()).name, 'Ada Obi');
    expect((await r.load()).phone, '08012345678');
    expect((await r.load()).phoneVisibility, 'after_enquiry');
  });
}

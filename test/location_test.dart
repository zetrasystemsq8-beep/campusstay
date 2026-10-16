import 'package:flutter_test/flutter_test.dart';
import 'package:campusstay/data/location_models.dart';

void main() {
  test('Nigerian numbers become wa.me numbers', () {
    expect(toInternationalPhone('08012345678'), '2348012345678');
    expect(toInternationalPhone('+234 801 234 5678'), '2348012345678');
    expect(toInternationalPhone('2348012345678'), '2348012345678');
  });

  test('prices are shortened for map pins', () {
    expect(compactNaira(150000), '₦150k');
    expect(compactNaira(1500000), '₦1.5M');
    expect(compactNaira(2000000), '₦2M');
    expect(compactNaira(800), '₦800');
  });
}

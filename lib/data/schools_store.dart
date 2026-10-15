import 'landlord_models.dart';
import 'repository.dart';

/// All schools are loaded once and searched on the phone, so the picker is instant.
class SchoolsStore {
  static List<University>? _cache;

  static Future<List<University>> load({bool force = false}) async {
    if (!force && _cache != null) return _cache!;
    _cache = await Services.landlord.universities();
    return _cache!;
  }
}

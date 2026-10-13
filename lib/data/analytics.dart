import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config.dart';

class Analytics {
  /// Counts one view of an approved listing. Failures are ignored on purpose.
  static Future<void> recordView(String propertyId) async {
    if (AppConfig.devMode) return;
    try {
      await Supabase.instance.client.rpc('record_view', params: {'p_property_id': propertyId});
    } catch (_) {}
  }
}

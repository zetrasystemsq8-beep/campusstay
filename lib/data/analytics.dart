import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config.dart';
import '../core/errors.dart';

class Analytics {
  /// Counts one view of an approved listing. This is a background counter, so a
  /// failure must not interrupt the student, but it is logged with its real cause.
  static Future<void> recordView(String propertyId) async {
    if (AppConfig.devMode) return;
    try {
      await Net.run(() => Supabase.instance.client.rpc('cs_record_view', params: {'p_property_id': propertyId}));
    } on AppException catch (e) {
      debugPrint('record_view failed: $e');
    }
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

/// True while the screen is showing a saved copy because the network is unavailable.
class OfflineState {
  static final ValueNotifier<bool> servingCache = ValueNotifier(false);
}

/// Keeps the last good copy of saved listings and of the first page of listings, so they still
/// open with no signal. It is cleared on log out so another person never sees your saved places.
class PropertyCache {
  static String _key(String k) => 'cs_cache_$k';

  static Future<void> write(String key, List<Property> items) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key(key), jsonEncode([for (final i in items) i.toJson()]));
    } catch (e) {
      debugPrint('cache write failed ($key): $e'); // a cache problem must never break the screen
    }
  }

  static Future<List<Property>?> read(String key) async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key(key));
      if (raw == null) return null;
      return [for (final m in (jsonDecode(raw) as List).cast<Map>()) Property.fromJson(Map<String, dynamic>.from(m))];
    } catch (e) {
      debugPrint('cache read failed ($key): $e');
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final p = await SharedPreferences.getInstance();
      for (final k in p.getKeys().where((k) => k.startsWith('cs_cache_')).toList()) {
        await p.remove(k);
      }
    } catch (e) {
      debugPrint('cache clear failed: $e');
    }
  }
}

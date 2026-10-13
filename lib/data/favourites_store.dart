import 'package:flutter/foundation.dart';
import 'repository.dart';

/// Shared saved-listing state so every screen agrees on what is saved.
class FavouritesStore {
  static final ValueNotifier<Set<String>> ids = ValueNotifier({});

  static Future<void> load() async {
    try {
      ids.value = await Services.repo.favouriteIds();
    } catch (_) {
      // Not signed in or offline: leave empty.
    }
  }

  /// Optimistic toggle; rolls back if the server rejects it.
  static Future<void> toggle(String id) async {
    final on = !ids.value.contains(id);
    final before = ids.value;
    ids.value = on ? {...before, id} : ({...before}..remove(id));
    try {
      await Services.repo.setFavourite(id, on);
    } catch (e) {
      ids.value = before;
      rethrow;
    }
  }
}

import 'package:flutter/foundation.dart';
import '../core/errors.dart';
import 'repository.dart';

/// Shared saved-listing state so every screen agrees on what is saved.
class FavouritesStore {
  static final ValueNotifier<Set<String>> ids = ValueNotifier({});

  /// Set when loading saved listings fails for a reason other than being signed out.
  static final ValueNotifier<Object?> loadError = ValueNotifier(null);

  static Future<void> load() async {
    loadError.value = null;
    try {
      ids.value = await Services.repo.favouriteIds();
    } on AppException catch (e) {
      if (e.kind != AppErrorKind.signInRequired) loadError.value = e;
    }
  }

  /// Optimistic toggle; rolls back and rethrows (typed) if the server refuses.
  static Future<void> toggle(String id) async {
    final on = !ids.value.contains(id);
    final before = ids.value;
    ids.value = on ? {...before, id} : ({...before}..remove(id));
    try {
      await Services.repo.setFavourite(id, on);
    } catch (_) {
      ids.value = before;
      rethrow;
    }
  }
}

import 'package:flutter/material.dart';
import '../../core/errors.dart';
import '../../core/widgets/error_views.dart';
import '../../core/widgets/offline_banner.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/property_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../data/favourites_store.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../property/property_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final void Function(String) onSearch;
  final VoidCallback onViewAll;
  final void Function(SearchFilter) onOpenFilter;
  const HomeScreen({super.key, required this.onSearch, required this.onViewAll, required this.onOpenFilter});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _savedRev = 0;
  late Future<List<Property>> _featured = Services.repo.search(const SearchFilter());

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: () async {
          setState(() => _featured = Services.repo.search(const SearchFilter()));
          await _featured;
        },
        child: ListView(padding: const EdgeInsets.all(CS.s16), children: [
          const OfflineBanner(),
          Text('Find your space', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text('Search by school, town or area.', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          TextField(
            textInputAction: TextInputAction.search,
            onSubmitted: widget.onSearch,
            decoration: const InputDecoration(hintText: 'Search by school, location, or area…', prefixIcon: Icon(Icons.search)),
          ),
          _SavedSearches(key: ValueKey(_savedRev), onOpen: widget.onOpenFilter, onChanged: () => setState(() => _savedRev++)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: Text('Featured listings', style: Theme.of(context).textTheme.titleLarge)),
            TextButton(onPressed: widget.onViewAll, child: const Text('View all')),
          ]),
          const SizedBox(height: 8),
          FutureBuilder<List<Property>>(
            future: _featured,
            builder: (c, s) {
              if (s.connectionState != ConnectionState.done) return const Column(children: [SkeletonCard(), SkeletonCard()]);
              if (s.hasError) {
                return ErrorView(error: s.error!, onRetry: () => setState(() => _featured = Services.repo.search(const SearchFilter())));
              }
              final list = s.data!.take(5).toList();
              if (list.isEmpty) {
                return const EmptyState(icon: Icons.home_work_outlined, title: 'No listings yet', message: 'Approved listings will appear here.');
              }
              return ValueListenableBuilder<Set<String>>(
                valueListenable: FavouritesStore.ids,
                builder: (c, favs, _) => Column(children: [
                  for (final p in list)
                    PropertyCard(
                      property: p,
                      saved: favs.contains(p.id),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PropertyDetailScreen(propertyId: p.id))),
                      onToggleSave: () => FavouritesStore.toggle(p.id).catchError((Object e) {
 if (context.mounted) showError(context, e);
 }),
                    ),
                ]),
              );
            },
          ),
        ]),
      );
}


/// Your saved searches, each with how many new places were approved since you last looked.
class _SavedSearches extends StatefulWidget {
  final void Function(SearchFilter) onOpen;
  final VoidCallback onChanged;
  const _SavedSearches({super.key, required this.onOpen, required this.onChanged});
  @override
  State<_SavedSearches> createState() => _SavedSearchesState();
}

class _SavedSearchesState extends State<_SavedSearches> {
  late final Future<List<(SavedSearch, int)>> _f = _load();

  Future<List<(SavedSearch, int)>> _load() async {
    final list = await Services.repo.savedSearches();
    final counts = await Future.wait([for (final s in list) Services.repo.countNewMatches(s)]);
    return [for (var i = 0; i < list.length; i++) (list[i], counts[i])];
  }

  Future<void> _open(SavedSearch s) async {
    try {
      await Services.repo.markSearchSeen(s.id);
    } catch (e) {
      if (mounted) showError(context, e);
    }
    widget.onOpen(s.filter);
  }

  Future<void> _delete(SavedSearch s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete "${s.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Services.repo.deleteSavedSearch(s.id);
      widget.onChanged();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<(SavedSearch, int)>>(
        future: _f,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) return const SizedBox.shrink();
          if (s.hasError) {
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(children: [
                Expanded(child: Text('Saved searches could not load: ${describe(s.error!).title}.', style: Theme.of(context).textTheme.bodySmall)),
                TextButton(onPressed: widget.onChanged, child: const Text('Retry')),
              ]),
            );
          }
          if (s.data!.isEmpty) return const SizedBox.shrink();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 20),
            Text('My saved searches', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in s.data!)
                InputChip(
                  avatar: e.$2 > 0 ? CircleAvatar(backgroundColor: CS.green, child: Text(e.$2 >= 10 ? '9+' : '${e.$2}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))) : const Icon(Icons.bookmark_outline, size: 18),
                  label: Text(e.$2 > 0 ? '${e.$1.name} · new' : e.$1.name),
                  onPressed: () => _open(e.$1),
                  onDeleted: () => _delete(e.$1),
                  deleteButtonTooltipMessage: 'Delete saved search',
                ),
            ]),
          ]);
        },
      );
}

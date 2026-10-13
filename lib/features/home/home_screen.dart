import 'package:flutter/material.dart';
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
  const HomeScreen({super.key, required this.onSearch, required this.onViewAll});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Property>> _featured = Services.repo.search(const SearchFilter());

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: () async {
          setState(() => _featured = Services.repo.search(const SearchFilter()));
          await _featured;
        },
        child: ListView(padding: const EdgeInsets.all(CS.s16), children: [
          Text('Find your space', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text('Search by school, town or area.', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          TextField(
            textInputAction: TextInputAction.search,
            onSubmitted: widget.onSearch,
            decoration: const InputDecoration(hintText: 'Search by school, location, or area…', prefixIcon: Icon(Icons.search)),
          ),
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
                return ErrorState(message: 'Could not load listings. Check your connection.', onRetry: () => setState(() => _featured = Services.repo.search(const SearchFilter())));
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
                      onToggleSave: () => FavouritesStore.toggle(p.id).catchError((_) {
                        if (context.mounted) showMessage(context, 'Sign in to save listings.', error: true);
                      }),
                    ),
                ]),
              );
            },
          ),
        ]),
      );
}

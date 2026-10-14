import 'package:flutter/material.dart';
import '../../core/widgets/error_views.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/property_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../data/favourites_store.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../property/property_detail_screen.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Set<String>>(
        valueListenable: FavouritesStore.ids,
        builder: (c, favs, _) => FutureBuilder<List<Property>>(
          key: ValueKey(favs.length),
          future: Services.repo.favourites(),
          builder: (c, s) {
            if (s.connectionState != ConnectionState.done) return const SkeletonList();
            if (s.hasError) return ErrorView(error: s.error!, onRetry: FavouritesStore.load);
            final list = s.data!;
            if (list.isEmpty) {
              return const EmptyState(icon: Icons.favorite_border, title: 'Nothing saved yet', message: 'Tap the heart on a listing to keep it here.');
            }
            return ListView(padding: const EdgeInsets.all(CS.s16), children: [
              for (final p in list)
                PropertyCard(
                  property: p,
                  saved: true,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PropertyDetailScreen(propertyId: p.id))),
                  onToggleSave: () => FavouritesStore.toggle(p.id),
                ),
            ]);
          },
        ),
      );
}

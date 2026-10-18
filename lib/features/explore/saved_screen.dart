import 'package:flutter/material.dart';
import '../../core/errors.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/error_views.dart';
import '../../core/widgets/offline_banner.dart';
import '../../core/widgets/property_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../data/favourites_store.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../property/property_detail_screen.dart';
import 'compare_screen.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});
  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  bool _compare = false;
  final _picked = <String>{};

  void _toggle(String id) {
    setState(() {
      if (_picked.contains(id)) {
        _picked.remove(id);
      } else if (_picked.length >= 3) {
        showError(context, const AppException(AppErrorKind.invalid, detail: 'You can compare up to 3 places at a time.'));
      } else {
        _picked.add(id);
      }
    });
  }

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
              return const EmptyState(icon: Icons.favorite_border, title: 'Nothing saved yet', message: 'Tap the heart on a listing to keep it here. Save two or three to compare them.');
            }
            return Column(children: [
              const OfflineBanner(),
              Padding(
                padding: const EdgeInsets.fromLTRB(CS.s16, CS.s16, CS.s8, 0),
                child: Row(children: [
                  Expanded(child: Text('Saved', style: Theme.of(context).textTheme.headlineMedium)),
                  if (list.length >= 2)
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _compare = !_compare;
                        _picked.clear();
                      }),
                      icon: Icon(_compare ? Icons.close : Icons.compare_arrows),
                      label: Text(_compare ? 'Cancel' : 'Compare'),
                    ),
                ]),
              ),
              if (_compare)
                const Padding(padding: EdgeInsets.fromLTRB(CS.s16, 4, CS.s16, 0), child: Align(alignment: Alignment.centerLeft, child: Text('Tap 2 or 3 places to compare.', style: TextStyle(color: CS.muted)))),
              Expanded(
                child: ListView(padding: const EdgeInsets.all(CS.s16), children: [
                  for (final p in list)
                    Stack(children: [
                      PropertyCard(
                        property: p,
                        saved: true,
                        onTap: _compare ? () => _toggle(p.id) : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PropertyDetailScreen(propertyId: p.id))),
                        onToggleSave: () => FavouritesStore.toggle(p.id).catchError((Object e) {
                          if (mounted) showError(context, e);
                        }),
                      ),
                      if (_compare)
                        Positioned.fill(
                          bottom: CS.s16,
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(CS.rLg),
                                border: Border.all(color: _picked.contains(p.id) ? CS.blue : Colors.transparent, width: 3),
                                color: _picked.contains(p.id) ? CS.blue.withValues(alpha: 0.08) : Colors.transparent,
                              ),
                              alignment: Alignment.topLeft,
                              padding: const EdgeInsets.all(10),
                              child: Icon(_picked.contains(p.id) ? Icons.check_circle : Icons.radio_button_unchecked, color: _picked.contains(p.id) ? CS.blue : Colors.white, size: 30),
                            ),
                          ),
                        ),
                    ]),
                ]),
              ),
              if (_compare)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(CS.s16, 4, CS.s16, CS.s12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: _picked.length < 2
                            ? null
                            : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CompareScreen(items: [for (final p in list) if (_picked.contains(p.id)) p]))),
                        child: Text(_picked.length < 2 ? 'Pick at least 2' : 'Compare ${_picked.length} places'),
                      ),
                    ),
                  ),
                ),
            ]);
          },
        ),
      );
}

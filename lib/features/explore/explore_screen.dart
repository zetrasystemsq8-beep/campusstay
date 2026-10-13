import 'package:flutter/material.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/property_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../data/favourites_store.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../property/property_detail_screen.dart';

class ExploreScreen extends StatefulWidget {
  final String initialQuery;
  const ExploreScreen({super.key, this.initialQuery = ''});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late SearchFilter _filter = SearchFilter(query: widget.initialQuery);
  late final _search = TextEditingController(text: widget.initialQuery);
  final _items = <Property>[];
  final _scroll = ScrollController();
  int _page = 0;
  bool _loading = true, _more = true, _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
    });
    _reload();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 0;
      _more = true;
    });
    try {
      final r = await Services.repo.search(_filter);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(r);
        _more = r.length == Repository.pageSize;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _error = 'Could not load listings. Check your connection.';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_more || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final r = await Services.repo.search(_filter, page: _page + 1);
      if (!mounted) return;
      setState(() {
        _page++;
        _items.addAll(r);
        _more = r.length == Repository.pageSize;
      });
    } catch (_) {
      if (mounted) showMessage(context, 'Could not load more listings.', error: true);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _openFilters() async {
    final f = await showModalBottomSheet<SearchFilter>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(CS.rLg))),
      builder: (_) => _FilterSheet(initial: _filter),
    );
    if (f != null) {
      _filter = f;
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(CS.s16, CS.s16, CS.s16, CS.s8),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (v) {
                  _filter = _filter.copyWith(query: v.trim());
                  _reload();
                },
                decoration: const InputDecoration(hintText: 'Search school, town or area', prefixIcon: Icon(Icons.search)),
              ),
            ),
            const SizedBox(width: 8),
            Badge(
              isLabelVisible: _filter.isActive,
              child: IconButton.filledTonal(onPressed: _openFilters, tooltip: 'Filters', icon: const Icon(Icons.tune)),
            ),
          ]),
        ),
        Expanded(child: _body()),
      ]);

  Widget _body() {
    if (_loading) return const SkeletonList();
    if (_error != null) return ErrorState(message: _error!, onRetry: _reload);
    if (_items.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: 'No listings match',
        message: 'Try a different search or clear your filters.',
        actionLabel: 'Clear filters',
        onAction: () {
          _search.clear();
          _filter = const SearchFilter();
          _reload();
        },
      );
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ValueListenableBuilder<Set<String>>(
        valueListenable: FavouritesStore.ids,
        builder: (c, favs, _) => ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.all(CS.s16),
          itemCount: _items.length + 1,
          itemBuilder: (c, i) {
            if (i == _items.length) {
              return _loadingMore ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())) : const SizedBox(height: 8);
            }
            final p = _items[i];
            return PropertyCard(
              property: p,
              saved: favs.contains(p.id),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PropertyDetailScreen(propertyId: p.id))),
              onToggleSave: () => FavouritesStore.toggle(p.id).catchError((_) {
                if (context.mounted) showMessage(context, 'Sign in to save listings.', error: true);
              }),
            );
          },
        ),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final SearchFilter initial;
  const _FilterSheet({required this.initial});
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late RangeValues _range = RangeValues((widget.initial.minRent ?? 0).toDouble(), (widget.initial.maxRent ?? 500000).toDouble());
  late String? _room = widget.initial.roomType;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(CS.s24, CS.s24, CS.s24, CS.s24 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Filters', style: Theme.of(context).textTheme.titleLarge)),
            TextButton(onPressed: () => Navigator.pop(context, SearchFilter(query: widget.initial.query)), child: const Text('Reset')),
          ]),
          const SizedBox(height: 12),
          Text('Rent range', style: Theme.of(context).textTheme.titleMedium),
          Text('₦${formatNaira(_range.start.round())} – ₦${formatNaira(_range.end.round())}${_range.end >= 500000 ? '+' : ''}',
              style: Theme.of(context).textTheme.bodySmall),
          RangeSlider(values: _range, min: 0, max: 500000, divisions: 50, onChanged: (v) => setState(() => _range = v)),
          const SizedBox(height: 8),
          Text('Room type', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in roomTypeLabels.entries)
              ChoiceChip(label: Text(e.value), selected: _room == e.key, onSelected: (s) => setState(() => _room = s ? e.key : null)),
          ]),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Apply filters',
            onPressed: () => Navigator.pop(
              context,
              SearchFilter(
                query: widget.initial.query,
                minRent: _range.start > 0 ? _range.start.round() : null,
                maxRent: _range.end < 500000 ? _range.end.round() : null,
                roomType: _room,
              ),
            ),
          ),
        ]),
      );
}

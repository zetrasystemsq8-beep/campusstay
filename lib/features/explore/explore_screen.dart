import 'package:flutter/material.dart';
import '../../core/errors.dart';
import 'map_screen.dart';
import '../../core/widgets/error_views.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/property_widgets.dart';
import '../../core/widgets/school_picker.dart';
import '../../core/widgets/state_views.dart';
import '../../data/favourites_store.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../property/property_detail_screen.dart';

class ExploreScreen extends StatefulWidget {
  final SearchFilter initialFilter;
  const ExploreScreen({super.key, this.initialFilter = const SearchFilter()});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late SearchFilter _filter = widget.initialFilter;
  late final _search = TextEditingController(text: widget.initialFilter.query);
  final _items = <Property>[];
  final _scroll = ScrollController();
  int _page = 0;
  bool _loading = true, _more = true, _loadingMore = false;
  Object? _error;

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
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
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
    } catch (e) {
      if (mounted) showError(context, e, onRetry: _loadMore);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  String get _suggestedName {
    final parts = <String>[
      if (_filter.roomType != null) roomTypeLabels[_filter.roomType] ?? '',
      if (_filter.schoolName != null) 'near ${_filter.schoolName}',
      if (_filter.query.isNotEmpty) _filter.query,
      if (_filter.maxRent != null) 'under ₦${formatNaira(_filter.maxRent!)}',
    ].where((e) => e.isNotEmpty).toList();
    return parts.isEmpty ? 'My search' : parts.join(' ');
  }

  Future<void> _saveSearch() async {
    final c = TextEditingController(text: _suggestedName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save this search'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: c, maxLength: 60, decoration: const InputDecoration(labelText: 'Name')),
          const Text('We will show how many new matching places appear, on your home screen.', style: TextStyle(color: CS.muted, fontSize: 13)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final t = c.text.trim();
              if (t.isNotEmpty) Navigator.pop(ctx, t);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    c.dispose();
    if (name == null || !mounted) return;
    try {
      final existing = await Services.repo.savedSearches();
      if (existing.length >= 10) {
        throw const AppException(AppErrorKind.invalid, detail: 'You can keep up to 10 saved searches. Delete one on the Home screen first.');
      }
      await Services.repo.saveSearch(name, _filter);
      if (mounted) showMessage(context, 'Saved. Look for it on your Home screen.');
    } catch (e) {
      if (mounted) showError(context, e);
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
            IconButton.filledTonal(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MapExploreScreen(filter: _filter))),
              tooltip: 'Map view',
              icon: const Icon(Icons.map_outlined),
            ),
            const SizedBox(width: 8),
            Badge(
              isLabelVisible: _filter.isActive,
              label: Text('${_filter.activeCount}'),
              child: IconButton.filledTonal(onPressed: _openFilters, tooltip: 'Filters', icon: const Icon(Icons.tune)),
            ),
          ]),
        ),
        if (_filter.query.isNotEmpty || _filter.isActive)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: CS.s8),
              child: TextButton.icon(onPressed: _saveSearch, icon: const Icon(Icons.bookmark_add_outlined, size: 20), label: const Text('Save this search')),
            ),
          ),
        Expanded(child: _body()),
      ]);

  Widget _body() {
    if (_loading) return const SkeletonList();
    if (_error != null) return ErrorView(error: _error!, onRetry: _reload);
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
              onToggleSave: () => FavouritesStore.toggle(p.id).catchError((Object e) {
 if (mounted) showError(context, e);
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
  late String? _schoolId = widget.initial.universityId;
  late String? _schoolName = widget.initial.schoolName;
  late String? _furnishing = widget.initial.furnishing;
  late String? _gender = widget.initial.forGender;
  late int? _beds = widget.initial.minBedrooms;
  late int? _walk = widget.initial.maxWalk;
  late final Set<String> _amen = {...widget.initial.amenities};

  Future<void> _pickSchool() async {
    final r = await pickSchool(context, allowClear: true);
    if (r == null) return;
    setState(() {
      _schoolId = r.school?.id;
      _schoolName = r.school?.shortName;
    });
  }

  Widget _h(String t) => Padding(padding: const EdgeInsets.only(top: 18, bottom: 8), child: Text(t, style: Theme.of(context).textTheme.titleMedium));

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(CS.s24, CS.s16, CS.s24, CS.s16 + MediaQuery.of(context).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Filters', style: Theme.of(context).textTheme.titleLarge)),
              TextButton(onPressed: () => Navigator.pop(context, SearchFilter(query: widget.initial.query)), child: const Text('Reset')),
            ]),
            Flexible(
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _h('School'),
                  OutlinedButton.icon(
                    onPressed: _pickSchool,
                    icon: const Icon(Icons.school_outlined),
                    label: Text(_schoolName ?? 'Any school'),
                  ),
                  _h('Rent range'),
                  Text('₦${formatNaira(_range.start.round())} – ₦${formatNaira(_range.end.round())}${_range.end >= 500000 ? '+' : ''}', style: Theme.of(context).textTheme.bodySmall),
                  RangeSlider(values: _range, min: 0, max: 500000, divisions: 50, onChanged: (v) => setState(() => _range = v)),
                  _h('Room type'),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final e in roomTypeLabels.entries) ChoiceChip(label: Text(e.value), selected: _room == e.key, onSelected: (s) => setState(() => _room = s ? e.key : null)),
                  ]),
                  _h('Bedrooms'),
                  Wrap(spacing: 8, children: [
                    ChoiceChip(label: const Text('Any'), selected: _beds == null, onSelected: (_) => setState(() => _beds = null)),
                    for (final n in [1, 2, 3, 4]) ChoiceChip(label: Text('$n+'), selected: _beds == n, onSelected: (_) => setState(() => _beds = n)),
                  ]),
                  _h('Walking time to school'),
                  Wrap(spacing: 8, children: [
                    ChoiceChip(label: const Text('Any'), selected: _walk == null, onSelected: (_) => setState(() => _walk = null)),
                    for (final n in [5, 10, 15, 20]) ChoiceChip(label: Text('$n min'), selected: _walk == n, onSelected: (_) => setState(() => _walk = n)),
                  ]),
                  _h('Furnishing'),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final e in furnishingLabels.entries) ChoiceChip(label: Text(e.value), selected: _furnishing == e.key, onSelected: (s) => setState(() => _furnishing = s ? e.key : null)),
                  ]),
                  _h('Suitable for'),
                  Wrap(spacing: 8, children: [
                    ChoiceChip(label: const Text('Anyone'), selected: _gender == null, onSelected: (_) => setState(() => _gender = null)),
                    ChoiceChip(label: const Text('Male student'), selected: _gender == 'male', onSelected: (s) => setState(() => _gender = s ? 'male' : null)),
                    ChoiceChip(label: const Text('Female student'), selected: _gender == 'female', onSelected: (s) => setState(() => _gender = s ? 'female' : null)),
                  ]),
                  _h('Must have'),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final a in amenityCatalog)
                      FilterChip(
                        label: Text(a.label),
                        selected: _amen.contains(a.code),
                        showCheckmark: false,
                        selectedColor: CS.blue,
                        labelStyle: TextStyle(color: _amen.contains(a.code) ? Colors.white : CS.ink, fontWeight: FontWeight.w600),
                        onSelected: (v) => setState(() => v ? _amen.add(a.code) : _amen.remove(a.code)),
                      ),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Show results',
              onPressed: () => Navigator.pop(
                context,
                SearchFilter(
                  query: widget.initial.query,
                  minRent: _range.start > 0 ? _range.start.round() : null,
                  maxRent: _range.end < 500000 ? _range.end.round() : null,
                  roomType: _room,
                  universityId: _schoolId,
                  schoolName: _schoolName,
                  furnishing: _furnishing,
                  forGender: _gender,
                  minBedrooms: _beds,
                  maxWalk: _walk,
                  amenities: _amen,
                ),
              ),
            ),
          ]),
        ),
      );
}

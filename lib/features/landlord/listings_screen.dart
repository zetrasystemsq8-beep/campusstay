import 'package:flutter/material.dart';
import '../../core/errors.dart';
import '../../core/widgets/error_views.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/landlord_theme.dart';
import '../../core/widgets/property_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../data/landlord_models.dart';
import '../../data/landlord_repository.dart';
import '../../data/repository.dart';
import '../property/reviews_widgets.dart';
import 'listing_wizard.dart';

class ListingsScreen extends StatefulWidget {
  final VoidCallback onAdd;
  const ListingsScreen({super.key, required this.onAdd});
  @override
  State<ListingsScreen> createState() => _ListingsScreenState();
}

class _Data {
  final List<LandlordListing> listings;
  final Map<String, ListingStats> stats;
  final Object? statsError;
  const _Data(this.listings, this.stats, this.statsError);
}

class _ListingsScreenState extends State<ListingsScreen> {
  late Future<_Data> _f = _load();
  void _reload() => setState(() => _f = _load());

  /// Listings are essential; statistics are extra. If only the statistics fail, the listings still
  /// show, with a visible message and a retry, so the real cause is never hidden.
  Future<_Data> _load() async {
    final listings = await Services.landlord.myListings();
    try {
      return _Data(listings, await Services.landlord.listingStats(), null);
    } catch (e) {
      return _Data(listings, const {}, e);
    }
  }

  Future<void> _changeSpaces(LandlordListing l, int delta) async {
    final cur = l.extras.spacesAvailable ?? 1;
    final next = (cur + delta).clamp(0, 500);
    if (next == cur) return;
    if (next == 0 && !await _confirm('Was that the last one?', 'The listing will be marked as rented and removed from search.', 'Yes, mark as rented')) return;
    await _run(() => Services.landlord.setSpaces(l.id, next, reopen: delta > 0 && l.availability == 'rented'),
        next == 0 ? 'Marked as rented.' : '$next space${next == 1 ? '' : 's'} left.');
  }

  Future<void> _run(Future<void> Function() action, String ok) async {
    try {
      await action();
      if (mounted) showMessage(context, ok);
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<bool> _confirm(String title, String body, String yes) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(yes)),
          ],
        ),
      ) ??
      false;

  Future<void> _edit(LandlordListing l) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ListingWizard(existing: l)));
    if (mounted) _reload();
  }

  Future<void> _onAction(String a, LandlordListing l) async {
    final r = Services.landlord;
    switch (a) {
      case 'edit':
        return _edit(l);
      case 'pause':
        return _run(() => r.setAvailability(l.id, 'paused'), 'Listing paused. Students cannot see it.');
      case 'resume':
        return _run(() => r.setAvailability(l.id, 'available'), 'Listing is live again.');
      case 'rented':
        if (await _confirm('Mark as rented?', 'It will be removed from search results.', 'Mark as rented')) {
          return _run(() => r.setAvailability(l.id, 'rented'), 'Marked as rented.');
        }
        return;
      case 'renew':
        return _run(() => r.renew(l.id), 'Confirmed for 60 more days.');
      case 'reviews':
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReviewsScreen(propertyId: l.id, title: 'Reviews of ${l.title}')));
        return;
      case 'copy':
        try {
          final id = await duplicateListing(r, l);
          final copy = await r.myListing(id);
          if (!mounted) return;
          showMessage(context, 'Copied. Add new photos and check the details.');
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ListingWizard(existing: copy)));
          if (mounted) _reload();
        } catch (e) {
          if (mounted) showError(context, e);
        }
        return;
      case 'delete':
        if (await _confirm('Delete this listing?', 'This cannot be undone.', 'Delete')) {
          return _run(() => r.delete(l.id), 'Listing deleted.');
        }
        return;
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(CS.s16, CS.s16, CS.s16, 0),
            child: Row(children: [
              Expanded(child: Text('My listings', style: Theme.of(context).textTheme.headlineMedium)),
              IconButton.filled(onPressed: widget.onAdd, tooltip: 'Add property', icon: const Icon(Icons.add)),
            ]),
          ),
          const TabBar(tabs: [Tab(text: 'Live'), Tab(text: 'In review'), Tab(text: 'Inactive')]),
          Expanded(
            child: FutureBuilder<_Data>(
              future: _f,
              builder: (c, s) {
                if (s.connectionState != ConnectionState.done) return const SkeletonList();
                if (s.hasError) return ErrorView(error: s.error!, onRetry: _reload);
                final data = s.data!;
                final all = data.listings;
                Widget tab(String bucket, String emptyTitle, String emptyMsg) {
                  final items = all.where((l) => l.bucket == bucket).toList();
                  if (items.isEmpty) {
                    return EmptyState(
                      icon: Icons.home_work_outlined,
                      title: emptyTitle,
                      message: emptyMsg,
                      actionLabel: bucket == 'inactive' ? null : 'Add property',
                      onAction: widget.onAdd,
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      _reload();
                      await _f;
                    },
                    child: ListView(padding: const EdgeInsets.all(CS.s16), children: [
                      if (data.statsError != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFFFFF4E0), borderRadius: BorderRadius.circular(CS.rMd)),
                          child: Row(children: [
                            Expanded(child: Text('Statistics could not load: ${describe(data.statsError!).title}.', style: const TextStyle(fontSize: 13))),
                            TextButton(onPressed: _reload, child: const Text('Retry')),
                          ]),
                        ),
                      for (final l in items) _Card(listing: l, stats: data.stats[l.id], onAction: (a) => _onAction(a, l), onSpaces: (d) => _changeSpaces(l, d)),
                    ]),
                  );
                }

                return TabBarView(children: [
                  tab('active', 'No live listings', 'Approved listings that are available show here.'),
                  tab('review', 'Nothing in review', 'Drafts and listings waiting for approval show here.'),
                  tab('inactive', 'Nothing inactive', 'Paused, rented and expired listings show here.'),
                ]);
              },
            ),
          ),
        ]),
      );
}

class _Card extends StatelessWidget {
  final LandlordListing listing;
  final void Function(String) onAction;
  final void Function(int) onSpaces;
  final ListingStats? stats;
  const _Card({required this.listing, required this.onAction, required this.onSpaces, this.stats});

  Color get _color => switch (listing.statusLabel) {
        'Live' => CS.green,
        'Pending review' => CS.warn,
        'Rejected' || 'Expired' => CS.danger,
        'Changes needed' => CS.warn,
        _ => CS.muted,
      };

  @override
  Widget build(BuildContext context) {
    final l = listing;
    final items = <PopupMenuEntry<String>>[
      const PopupMenuItem(value: 'edit', child: Text('Edit')),
      const PopupMenuItem(value: 'copy', child: Text('Copy this listing')),
      if (l.moderation == 'approved') const PopupMenuItem(value: 'reviews', child: Text('See reviews')),
      if (l.isActive) const PopupMenuItem(value: 'pause', child: Text('Pause listing')),
      if (l.isActive) const PopupMenuItem(value: 'rented', child: Text('Mark as rented')),
      if (l.moderation == 'approved' && l.availability == 'paused') const PopupMenuItem(value: 'resume', child: Text('Make live again')),
      if (l.moderation == 'approved' && (l.isExpired || (l.daysLeft ?? 99) <= 7)) const PopupMenuItem(value: 'renew', child: Text('Confirm still available')),
      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: CS.danger))),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: CS.s16),
      decoration: BoxDecoration(color: CS.bg, borderRadius: BorderRadius.circular(CS.rLg), border: Border.all(color: CS.line), boxShadow: CS.shadow),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PropertyPhoto(url: l.photos.isEmpty ? null : l.photos.first.url, height: 120),
        Padding(
          padding: const EdgeInsets.all(CS.s16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(l.title, style: Theme.of(context).textTheme.titleMedium)),
              PopupMenuButton<String>(tooltip: 'Listing actions', onSelected: onAction, itemBuilder: (_) => items),
            ]),
            Text('${l.area}, ${l.school} · ${l.roomTypeLabel}', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Row(children: [
              Text(l.rentLabel, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: CS.green)),
              const Spacer(),
              StatusBadge(l.statusLabel, _color),
            ]),
            const SizedBox(height: 8),
            VerificationBadge(l.verification),
            const SizedBox(height: 10),
            Wrap(spacing: 14, runSpacing: 6, children: [
              _Stat(Icons.visibility_outlined, '${stats?.views ?? l.views}', 'views'),
              if (stats != null) ...[
                _Stat(Icons.favorite_border, '${stats!.saves}', 'saved'),
                _Stat(Icons.chat_bubble_outline, '${stats!.enquiries}', 'enquiries'),
                _Stat(Icons.event_available_outlined, '${stats!.viewings}', 'viewings'),
              ],
            ]),
            if (l.extras.spacesAvailable != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  const Icon(Icons.meeting_room_outlined, size: 20, color: CS.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.extras.spacesAvailable == 0 ? 'No spaces left' : '${l.extras.spacesAvailable} space${l.extras.spacesAvailable == 1 ? '' : 's'} left',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton.outlined(tooltip: 'Someone took one', onPressed: (l.extras.spacesAvailable ?? 0) > 0 ? () => onSpaces(-1) : null, icon: const Icon(Icons.remove)),
                  IconButton.outlined(tooltip: 'Add a space', onPressed: () => onSpaces(1), icon: const Icon(Icons.add)),
                ]),
              ),
            if ((l.moderationNote ?? '').isNotEmpty && (l.moderation == 'rejected' || l.moderation == 'needs_changes'))
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFFF4E0), borderRadius: BorderRadius.circular(CS.rSm)),
                child: Text('Reviewer note: ${l.moderationNote}', style: const TextStyle(fontSize: 13)),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value, label;
  const _Stat(this.icon, this.value, this.label);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: CS.muted),
        const SizedBox(width: 4),
        Text('$value $label', style: Theme.of(context).textTheme.bodySmall),
      ]);
}

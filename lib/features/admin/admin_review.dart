import 'package:flutter/material.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/error_views.dart';
import '../../core/widgets/property_details_widgets.dart';
import '../../core/widgets/property_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../data/landlord_models.dart';
import '../../data/repository.dart';

/// Asks for a note. Returns null if cancelled.
Future<String?> askNote(BuildContext context, {required String title, required String action, bool required = true, String hint = 'Reason'}) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      String? err;
      return StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(title),
          content: TextField(controller: c, maxLines: 4, maxLength: 1000, decoration: InputDecoration(hintText: hint, errorText: err)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final t = c.text.trim();
                if (required && t.length < 3) {
                  set(() => err = 'Please write a short reason.');
                  return;
                }
                Navigator.pop(ctx, t);
              },
              child: Text(action),
            ),
          ],
        ),
      );
    },
  );
}

class ReviewQueueScreen extends StatefulWidget {
  final VoidCallback onChanged;
  const ReviewQueueScreen({super.key, required this.onChanged});
  @override
  State<ReviewQueueScreen> createState() => _ReviewQueueScreenState();
}

class _ReviewQueueScreenState extends State<ReviewQueueScreen> {
  late Future<List<LandlordListing>> _f = Services.admin.pendingListings();
  void _reload() => setState(() => _f = Services.admin.pendingListings());

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(CS.s16, CS.s16, CS.s16, CS.s8), child: Text('Listings to review', style: Theme.of(context).textTheme.headlineMedium)),
        Expanded(
          child: FutureBuilder<List<LandlordListing>>(
            future: _f,
            builder: (c, s) {
              if (s.connectionState != ConnectionState.done) return const SkeletonList();
              if (s.hasError) return ErrorView(error: s.error!, onRetry: _reload);
              if (s.data!.isEmpty) return const EmptyState(icon: Icons.task_alt, title: 'All caught up', message: 'New submissions waiting for review appear here.');
              return RefreshIndicator(
                onRefresh: () async {
                  _reload();
                  await _f;
                },
                child: ListView(padding: const EdgeInsets.all(CS.s16), children: [
                  for (final l in s.data!)
                    GestureDetector(
                      onTap: () async {
                        final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => ListingReviewScreen(listing: l)));
                        if (changed == true) widget.onChanged();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: CS.s12),
                        decoration: BoxDecoration(color: CS.bg, borderRadius: BorderRadius.circular(CS.rLg), border: Border.all(color: CS.line), boxShadow: CS.shadow),
                        clipBehavior: Clip.antiAlias,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          PropertyPhoto(url: l.photos.isEmpty ? null : l.photos.first.url, height: 110),
                          Padding(
                            padding: const EdgeInsets.all(CS.s12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(l.title, style: Theme.of(context).textTheme.titleMedium),
                              Text('${l.area}, ${l.school} · ${l.rentLabel}', style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 6),
                              VerificationBadge(l.verification),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                ]),
              );
            },
          ),
        ),
      ]);
}

class ListingReviewScreen extends StatefulWidget {
  final LandlordListing listing;
  const ListingReviewScreen({super.key, required this.listing});
  @override
  State<ListingReviewScreen> createState() => _ListingReviewScreenState();
}

class _ListingReviewScreenState extends State<ListingReviewScreen> {
  bool _busy = false;

  Future<void> _decide(String decision, {bool needNote = true}) async {
    final note = await askNote(context,
        title: switch (decision) { 'approved' => 'Approve this listing?', 'rejected' => 'Reject this listing', _ => 'Request changes' },
        action: switch (decision) { 'approved' => 'Approve', 'rejected' => 'Reject', _ => 'Send request' },
        required: needNote,
        hint: decision == 'approved' ? 'Optional note' : 'Tell the landlord what to fix or why it was rejected');
    if (note == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await Services.admin.moderate(widget.listing.id, decision, note);
      if (mounted) {
        showMessage(context, decision == 'approved' ? 'Approved. The listing is live for 60 days.' : 'Decision sent to the landlord.');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _suspendOwner() async {
    final owner = widget.listing.ownerId;
    if (owner == null) return;
    final reason = await askNote(context, title: 'Suspend this landlord?', action: 'Suspend', hint: 'Reason (recorded in the audit log)');
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await Services.admin.setSuspension(owner, true, reason);
      if (mounted) showMessage(context, 'Account suspended.');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.listing;
    return Scaffold(
      appBar: AppBar(title: const Text('Review listing')),
      body: Column(children: [
        Expanded(
          child: ListView(padding: EdgeInsets.zero, children: [
            SizedBox(
              height: 220,
              child: l.photos.isEmpty
                  ? const PropertyPhoto(height: 220)
                  : PageView(children: [for (final p in l.photos) PropertyPhoto(url: p.url, height: 220)]),
            ),
            Padding(
              padding: const EdgeInsets.all(CS.s16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text('${l.area}, ${l.school}${l.distanceKm == null ? '' : ' · ${l.distanceKm} km'}', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 10),
                Text(l.rentLabel, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: CS.blue)),
                const SizedBox(height: 10),
                VerificationBadge(l.verification),
                const SizedBox(height: 10),
                PropertyFacts(extras: l.extras, roomTypeLabel: l.roomTypeLabel),
                if (l.universityId == null && l.extras.schoolOther.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 8), child: Text('School not on the list: ${l.extras.schoolOther}. Add it to cs_universities if it is real.', style: const TextStyle(color: CS.warn, fontWeight: FontWeight.w600))),
                if (l.extras.landmark.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Landmark: ${l.extras.landmark}')),
                FacilitiesByCategory(codes: l.amenities),
                const SizedBox(height: 14),
                Text(l.description.isEmpty ? 'No description.' : l.description),
                const SizedBox(height: 14),
                CostsCard(rentLabel: l.rentLabel, rentNgn: l.rentNgn, extras: l.extras, otherFees: l.extraFees),
                const SizedBox(height: 10),
                RulesCard(extras: l.extras),
                const SizedBox(height: 14),
                Text('${l.photos.length} photo${l.photos.length == 1 ? '' : 's'}. Check they match the description and are not stock images.', style: Theme.of(context).textTheme.bodySmall),
                if (l.verification != 'verified')
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Approving a listing does not verify the landlord. Verification is a separate step under Verification documents.', style: TextStyle(color: CS.muted, fontSize: 12.5)),
                  ),
              ]),
            ),
          ]),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(CS.s16, CS.s8, CS.s16, CS.s12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              PrimaryButton(label: 'Approve', color: CS.green, loading: _busy, onPressed: () => _decide('approved', needNote: false)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: _busy ? null : () => _decide('needs_changes'), child: const Text('Request changes'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: CS.danger), onPressed: _busy ? null : () => _decide('rejected'), child: const Text('Reject'))),
              ]),
              TextButton(onPressed: _busy ? null : _suspendOwner, child: const Text('Suspend this landlord', style: TextStyle(color: CS.danger))),
            ]),
          ),
        ),
      ]),
    );
  }
}

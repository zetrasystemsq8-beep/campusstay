import 'package:flutter/material.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/error_views.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models.dart';
import '../../data/repository.dart';

class StarRow extends StatelessWidget {
  final double value;
  final double size;
  const StarRow({super.key, required this.value, this.size = 18});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= 5; i++) Icon(value >= i ? Icons.star : (value >= i - 0.5 ? Icons.star_half : Icons.star_border), size: size, color: const Color(0xFFF5A623)),
      ]);
}

class _Data {
  final ReviewSummary summary;
  final List<Review> reviews;
  final String can;
  const _Data(this.summary, this.reviews, this.can);
}

Future<_Data> _load(String id) async {
  final r = await Future.wait([Services.repo.reviewSummary(id), Services.repo.reviews(id), Services.repo.canReview(id)]);
  return _Data(r[0] as ReviewSummary, r[1] as List<Review>, r[2] as String);
}

/// Only students who actually viewed the place (a confirmed viewing that has happened) can review it.
Future<void> writeReview(BuildContext context, String propertyId, {Review? existing}) async {
  var rating = existing?.rating ?? 0;
  final c = TextEditingController(text: existing?.comment ?? '');
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(existing == null ? 'Rate this place' : 'Edit your review'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  tooltip: '$i star${i == 1 ? '' : 's'}',
                  onPressed: () => set(() => rating = i),
                  icon: Icon(rating >= i ? Icons.star : Icons.star_border, size: 34, color: const Color(0xFFF5A623)),
                ),
            ]),
            TextField(controller: c, maxLines: 4, maxLength: 1000, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'What was it like? (optional)')),
            const Text('Your name is not shown with your review.', style: TextStyle(color: CS.muted, fontSize: 12.5)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: rating == 0 ? null : () => Navigator.pop(ctx, true), child: const Text('Post')),
        ],
      ),
    ),
  );
  final text = c.text.trim();
  c.dispose();
  if (ok != true || !context.mounted) return;
  try {
    await Services.repo.submitReview(propertyId, rating, text);
    if (context.mounted) showMessage(context, 'Thank you. Your review is posted.');
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}

class _Tile extends StatelessWidget {
  final Review review;
  final bool ownerMode;
  final VoidCallback onChanged;
  const _Tile({required this.review, required this.ownerMode, required this.onChanged});

  Future<void> _report(BuildContext context) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(title: const Text('Report this review'), children: [
        for (final r in const ['Fake or not a real tenant', 'Rude or abusive', 'Private information', 'Other']) SimpleDialogOption(onPressed: () => Navigator.pop(c, r), child: Text(r)),
      ]),
    );
    if (reason == null || !context.mounted) return;
    try {
      await Services.repo.report('review', review.id, reason, '');
      if (context.mounted) showMessage(context, 'Report sent. Our team will look at it.');
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _reply(BuildContext context) async {
    final c = TextEditingController(text: review.reply);
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reply to this review'),
        content: TextField(controller: c, maxLines: 4, maxLength: 1000, decoration: const InputDecoration(hintText: 'Be polite and helpful. Everyone can see your reply.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Post reply')),
        ],
      ),
    );
    c.dispose();
    if (text == null || !context.mounted) return;
    try {
      await Services.landlord.replyToReview(review.id, text);
      onChanged();
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(CS.rMd), border: Border.all(color: CS.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            StarRow(value: review.rating.toDouble(), size: 17),
            const SizedBox(width: 8),
            Expanded(child: Text(review.mine ? 'Your review' : 'A student who viewed this place', style: Theme.of(context).textTheme.bodySmall)),
            if (!review.mine && !ownerMode) IconButton(tooltip: 'Report review', visualDensity: VisualDensity.compact, icon: const Icon(Icons.flag_outlined, size: 18), onPressed: () => _report(context)),
          ]),
          if (review.comment.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(review.comment)),
          Padding(padding: const EdgeInsets.only(top: 6), child: Text(fmtDate(review.createdAt), style: Theme.of(context).textTheme.bodySmall)),
          if (review.reply.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: CS.surface, borderRadius: BorderRadius.circular(CS.rSm)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("Landlord's reply", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                Text(review.reply),
              ]),
            ),
          if (ownerMode) TextButton(onPressed: () => _reply(context), child: Text(review.reply.isEmpty ? 'Reply' : 'Edit reply')),
        ]),
      );
}

class ReviewsSection extends StatefulWidget {
  final String propertyId;
  final String title;
  const ReviewsSection({super.key, required this.propertyId, this.title = 'Reviews'});
  @override
  State<ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<ReviewsSection> {
  late Future<_Data> _f = _load(widget.propertyId);
  void _reload() => setState(() => _f = _load(widget.propertyId));

  @override
  Widget build(BuildContext context) => FutureBuilder<_Data>(
        future: _f,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) return const SizedBox(height: 40);
          if (s.hasError) {
            return Row(children: [
              Expanded(child: Text('Reviews could not load: ${describe(s.error!).title}.', style: Theme.of(context).textTheme.bodySmall)),
              TextButton(onPressed: _reload, child: const Text('Retry')),
            ]);
          }
          final d = s.data!;
          final mine = d.reviews.where((r) => r.mine).firstOrNull;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (d.summary.count > 0) ...[StarRow(value: d.summary.average), const SizedBox(width: 6), Text('${d.summary.average} (${d.summary.count})', style: const TextStyle(fontWeight: FontWeight.w800))],
            ]),
            const SizedBox(height: 8),
            if (d.reviews.isEmpty) const Text('No reviews yet. Only students who have viewed the place can review it.', style: TextStyle(color: CS.muted)),
            for (final r in d.reviews.take(3)) _Tile(review: r, ownerMode: false, onChanged: _reload),
            if (d.reviews.length > 3)
              TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReviewsScreen(propertyId: widget.propertyId, title: 'All reviews'))), child: Text('See all ${d.reviews.length} reviews')),
            if (d.can == 'yes' || d.can == 'edit')
              OutlinedButton.icon(
                onPressed: () async {
                  await writeReview(context, widget.propertyId, existing: mine);
                  if (mounted) _reload();
                },
                icon: const Icon(Icons.rate_review_outlined),
                label: Text(d.can == 'edit' ? 'Edit your review' : 'Write a review'),
              ),
          ]);
        },
      );
}

/// Full list. The landlord opens this from "Reviews" on a listing and can reply to each one.
class ReviewsScreen extends StatefulWidget {
  final String propertyId;
  final String title;
  const ReviewsScreen({super.key, required this.propertyId, required this.title});
  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  late Future<_Data> _f = _load(widget.propertyId);
  void _reload() => setState(() => _f = _load(widget.propertyId));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: FutureBuilder<_Data>(
          future: _f,
          builder: (c, s) {
            if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (s.hasError) return ErrorView(error: s.error!, onRetry: _reload);
            final d = s.data!;
            if (d.reviews.isEmpty) return const EmptyState(icon: Icons.star_border, title: 'No reviews yet', message: 'Students who view a place can review it afterwards.');
            return RefreshIndicator(
              onRefresh: () async {
                _reload();
                await _f;
              },
              child: ListView(padding: const EdgeInsets.all(CS.s16), children: [
                Row(children: [StarRow(value: d.summary.average, size: 24), const SizedBox(width: 8), Text('${d.summary.average} from ${d.summary.count}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))]),
                const SizedBox(height: 12),
                for (final r in d.reviews) _Tile(review: r, ownerMode: d.can == 'own', onChanged: _reload),
              ]),
            );
          },
        ),
      );
}

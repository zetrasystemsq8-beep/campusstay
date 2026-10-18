import 'package:flutter/material.dart';
import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/error_views.dart';
import '../../core/widgets/state_views.dart';
import '../../data/admin_models.dart';
import '../../data/repository.dart';
import '../property/property_detail_screen.dart';
import 'admin_review.dart';

class ReportsScreen extends StatefulWidget {
  final VoidCallback onChanged;
  const ReportsScreen({super.key, required this.onChanged});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _openOnly = true;
  late Future<List<AdminReport>> _f = Services.admin.reports();
  void _reload() => setState(() => _f = Services.admin.reports(openOnly: _openOnly));

  Future<void> _run(Future<void> Function() action, String ok) async {
    try {
      await action();
      if (mounted) showMessage(context, ok);
      widget.onChanged();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _removeListing(AdminReport r) async {
    final note = await askNote(context, title: 'Remove this listing?', action: 'Remove', hint: 'Reason shown to the landlord');
    if (note == null) return;
    await _run(() async {
      await Services.admin.moderate(r.targetId, 'rejected', note);
      await Services.admin.resolveReport(r.id, 'actioned', 'Listing removed: $note');
    }, 'Listing removed and report closed.');
  }

  Future<void> _suspend(AdminReport r) async {
    final note = await askNote(context, title: 'Suspend this account?', action: 'Suspend', hint: 'Reason (recorded in the audit log)');
    if (note == null) return;
    await _run(() async {
      await Services.admin.setSuspension(r.targetId, true, note);
      await Services.admin.resolveReport(r.id, 'actioned', 'Account suspended: $note');
    }, 'Account suspended and report closed.');
  }

  Future<void> _removeReview(AdminReport r) async {
    final note = await askNote(context, title: 'Remove this review?', action: 'Remove', hint: 'Reason (recorded in the audit log)');
    if (note == null) return;
    await _run(() async {
      await Services.admin.deleteReview(r.targetId, note);
      await Services.admin.resolveReport(r.id, 'actioned', 'Review removed: $note');
    }, 'Review removed and report closed.');
  }

  Future<void> _dismiss(AdminReport r) async {
    final note = await askNote(context, title: 'Dismiss this report', action: 'Dismiss', hint: 'Why is no action needed?');
    if (note == null) return;
    await _run(() => Services.admin.resolveReport(r.id, 'dismissed', note), 'Report dismissed.');
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(CS.s16, CS.s16, CS.s16, 0),
          child: Row(children: [
            Expanded(child: Text('Reports', style: Theme.of(context).textTheme.headlineMedium)),
            FilterChip(
              label: const Text('Open only'),
              selected: _openOnly,
              onSelected: (v) {
                _openOnly = v;
                _reload();
              },
            ),
          ]),
        ),
        Expanded(
          child: FutureBuilder<List<AdminReport>>(
            future: _f,
            builder: (c, s) {
              if (s.connectionState != ConnectionState.done) return const SkeletonList();
              if (s.hasError) return ErrorView(error: s.error!, onRetry: _reload);
              if (s.data!.isEmpty) return const EmptyState(icon: Icons.verified_outlined, title: 'No reports', message: 'Nothing has been reported. Quiet is good.');
              return RefreshIndicator(
                onRefresh: () async {
                  _reload();
                  await _f;
                },
                child: ListView(padding: const EdgeInsets.all(CS.s16), children: [
                  for (final r in s.data!)
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CS.rMd), side: const BorderSide(color: CS.line)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r.targetType == 'property' ? (r.targetTitle ?? 'Listing (removed)') : 'Reported ${r.targetType}', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text('${r.reason} · ${fmtDateTime(r.createdAt)} · ${r.status}', style: Theme.of(context).textTheme.bodySmall),
                          if ((r.details ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(r.details!)),
                          const SizedBox(height: 10),
                          if (r.status == 'open' || r.status == 'reviewing')
                            Wrap(spacing: 8, children: [
                              if (r.targetType == 'property') ...[
                                OutlinedButton(
                                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PropertyDetailScreen(propertyId: r.targetId))),
                                  child: const Text('View listing'),
                                ),
                                OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: CS.danger), onPressed: () => _removeListing(r), child: const Text('Remove listing')),
                              ],
                              if (r.targetType == 'review') OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: CS.danger), onPressed: () => _removeReview(r), child: const Text('Remove review')),
                              if (r.targetType == 'user') OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: CS.danger), onPressed: () => _suspend(r), child: const Text('Suspend user')),
                              TextButton(onPressed: () => _dismiss(r), child: const Text('Dismiss')),
                            ]),
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

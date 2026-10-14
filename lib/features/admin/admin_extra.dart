import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/error_views.dart';
import '../../core/widgets/state_views.dart';
import '../../data/admin_models.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import 'admin_review.dart';

const _docNames = {'id_card': 'ID card', 'agreement': 'Agreement or authorisation', 'property_document': 'Property document'};

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});
  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  late Future<List<VerificationItem>> _f = Services.admin.verifications();
  void _reload() => setState(() => _f = Services.admin.verifications());

  Future<void> _view(VerificationItem v) async {
    try {
      final url = await Services.admin.signedDocUrl(v.path);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => Dialog(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  loadingBuilder: (c, child, p) => p == null ? child : const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()),
                  errorBuilder: (c, e, s) => const Padding(padding: EdgeInsets.all(24), child: Text('This file could not be shown as an image. It may be a PDF or an unsupported format.')),
                ),
              ),
            ),
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close')),
          ]),
        ),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _review(VerificationItem v, bool approve) async {
    final note = await askNote(context,
        title: approve ? 'Approve this document?' : 'Reject this document',
        action: approve ? 'Approve' : 'Reject',
        required: !approve,
        hint: approve ? 'Optional note' : 'What is wrong with it?');
    if (note == null) return;
    try {
      await Services.admin.reviewVerification(v.id, approve, note);
      if (mounted) showMessage(context, approve ? 'Approved. The listing is marked verified.' : 'Rejected.');
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Verification documents')),
        body: FutureBuilder<List<VerificationItem>>(
          future: _f,
          builder: (c, s) {
            if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (s.hasError) return ErrorView(error: s.error!, onRetry: _reload);
            if (s.data!.isEmpty) return const EmptyState(icon: Icons.verified_user_outlined, title: 'Nothing to check', message: 'Uploaded IDs and ownership proof appear here.');
            return ListView(padding: const EdgeInsets.all(CS.s16), children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('Only approve after you have checked that the ID matches the landlord and the document is genuine. Approval marks the listing as Verified.', style: TextStyle(color: CS.muted)),
              ),
              for (final v in s.data!)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CS.rMd), side: const BorderSide(color: CS.line)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_docNames[v.docType] ?? v.docType, style: Theme.of(context).textTheme.titleMedium),
                      Text('${v.propertyTitle} · ${fmtDateTime(v.createdAt)}', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, children: [
                        OutlinedButton(onPressed: () => _view(v), child: const Text('View document')),
                        FilledButton(onPressed: () => _review(v, true), child: const Text('Approve')),
                        OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: CS.danger), onPressed: () => _review(v, false), child: const Text('Reject')),
                      ]),
                    ]),
                  ),
                ),
            ]);
          },
        ),
      );
}

class LeadsScreen extends StatefulWidget {
  final VoidCallback onChanged;
  const LeadsScreen({super.key, required this.onChanged});
  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  late Future<List<LeadItem>> _f = Services.admin.leads();
  void _reload() => setState(() => _f = Services.admin.leads());

  Future<void> _set(LeadItem l, String status) async {
    try {
      await Services.admin.setLeadStatus(l.id, status);
      if (mounted) showMessage(context, 'Marked as $status.');
      widget.onChanged();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(CS.s16, CS.s16, CS.s16, CS.s8), child: Text('Landlord leads', style: Theme.of(context).textTheme.headlineMedium)),
        const Padding(padding: EdgeInsets.symmetric(horizontal: CS.s16), child: Text('From the public web form. Nothing here is published. Call the landlord, then help them create a listing.', style: TextStyle(color: CS.muted))),
        Expanded(
          child: FutureBuilder<List<LeadItem>>(
            future: _f,
            builder: (c, s) {
              if (s.connectionState != ConnectionState.done) return const SkeletonList();
              if (s.hasError) return ErrorView(error: s.error!, onRetry: _reload);
              if (s.data!.isEmpty) return const EmptyState(icon: Icons.contact_phone_outlined, title: 'No leads yet', message: 'Share the landlord page link on WhatsApp to get started.');
              return RefreshIndicator(
                onRefresh: () async {
                  _reload();
                  await _f;
                },
                child: ListView(padding: const EdgeInsets.all(CS.s16), children: [
                  for (final l in s.data!)
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CS.rMd), side: const BorderSide(color: CS.line)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(l.name, style: Theme.of(context).textTheme.titleMedium),
                          SelectableText(l.phone, style: const TextStyle(fontWeight: FontWeight.w700, color: CS.blue)),
                          Text('${l.schoolOrArea} · ${roomTypeLabels[l.roomType] ?? l.roomType}${l.rentNgn == null ? '' : ' · ₦${formatNaira(l.rentNgn!)}'}', style: Theme.of(context).textTheme.bodySmall),
                          if ((l.description ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(l.description!)),
                          const SizedBox(height: 8),
                          Text('${l.status} · ${fmtDateTime(l.createdAt)}', style: Theme.of(context).textTheme.bodySmall),
                          Wrap(spacing: 8, children: [
                            TextButton(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: l.phone));
                                showMessage(context, 'Number copied.');
                              },
                              child: const Text('Copy number'),
                            ),
                            if (l.status == 'new') TextButton(onPressed: () => _set(l, 'contacted'), child: const Text('Contacted')),
                            TextButton(onPressed: () => _set(l, 'converted'), child: const Text('Listed')),
                            TextButton(onPressed: () => _set(l, 'dismissed'), child: const Text('Dismiss')),
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

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});
  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  late Future<List<AuditItem>> _f = Services.admin.audit();
  void _reload() => setState(() => _f = Services.admin.audit());

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Audit log')),
        body: FutureBuilder<List<AuditItem>>(
          future: _f,
          builder: (c, s) {
            if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (s.hasError) return ErrorView(error: s.error!, onRetry: _reload);
            if (s.data!.isEmpty) return const EmptyState(icon: Icons.history, title: 'No activity yet', message: 'Admin actions will be recorded here.');
            return ListView.separated(
              itemCount: s.data!.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (c, i) {
                final a = s.data![i];
                return ListTile(
                  title: Text(a.action.replaceAll('_', ' '), style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${a.targetType} · ${fmtDateTime(a.createdAt)}\n${jsonEncode(a.details)}'),
                  isThreeLine: true,
                );
              },
            );
          },
        ),
      );
}

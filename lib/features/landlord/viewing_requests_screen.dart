import 'package:flutter/material.dart';
import '../../core/widgets/error_views.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/landlord_theme.dart';
import '../../core/widgets/state_views.dart';
import '../../data/landlord_models.dart';
import '../../data/repository.dart';

String _fmt(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const w = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final hh = d.hour.toString().padLeft(2, '0'), mm = d.minute.toString().padLeft(2, '0');
  return '${w[d.weekday - 1]} ${d.day} ${m[d.month - 1]}, $hh:$mm';
}

class ViewingRequestsScreen extends StatefulWidget {
  const ViewingRequestsScreen({super.key});
  @override
  State<ViewingRequestsScreen> createState() => _ViewingRequestsScreenState();
}

class _ViewingRequestsScreenState extends State<ViewingRequestsScreen> {
  late Future<List<ViewingRequestItem>> _f = Services.landlord.viewingRequests();
  void _reload() => setState(() => _f = Services.landlord.viewingRequests());

  Future<void> _decide(ViewingRequestItem r, String status) async {
    try {
      await Services.landlord.decideViewing(r.id, status);
      if (mounted) showMessage(context, status == 'confirmed' ? 'Viewing confirmed.' : 'Viewing declined.');
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => LandlordThemed(
        child: Scaffold(
          appBar: AppBar(title: const Text('Viewing requests')),
          body: FutureBuilder<List<ViewingRequestItem>>(
            future: _f,
            builder: (c, s) {
              if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
              if (s.hasError) return ErrorView(error: s.error!, onRetry: _reload);
              if (s.data!.isEmpty) {
                return const EmptyState(icon: Icons.event_available_outlined, title: 'No viewing requests', message: 'When a student asks to view a property, it appears here.');
              }
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
                          Text(r.propertyTitle, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text('Preferred: ${_fmt(r.preferredAt)}'),
                          if ((r.note ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Note: ${r.note}', style: Theme.of(context).textTheme.bodySmall)),
                          const SizedBox(height: 10),
                          if (r.status == 'requested')
                            Row(children: [
                              Expanded(child: OutlinedButton(onPressed: () => _decide(r, 'declined'), child: const Text('Decline'))),
                              const SizedBox(width: 10),
                              Expanded(child: FilledButton(onPressed: () => _decide(r, 'confirmed'), child: const Text('Confirm'))),
                            ])
                          else
                            StatusBadge(r.status[0].toUpperCase() + r.status.substring(1), r.status == 'confirmed' ? CS.green : CS.muted),
                        ]),
                      ),
                    ),
                ]),
              );
            },
          ),
        ),
      );
}

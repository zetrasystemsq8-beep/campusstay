import 'package:flutter/material.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/state_views.dart';
import '../../data/landlord_models.dart';
import '../../data/repository.dart';
import 'viewing_requests_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onAdd;
  final VoidCallback onOpenListings;
  final VoidCallback onChanged;
  const DashboardScreen({super.key, required this.onAdd, required this.onOpenListings, required this.onChanged});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<(DashboardStats, List<LandlordListing>)> _f = _load();

  Future<(DashboardStats, List<LandlordListing>)> _load() async {
    final r = await Future.wait([Services.landlord.stats(), Services.landlord.myListings()]);
    return (r[0] as DashboardStats, r[1] as List<LandlordListing>);
  }

  void _reload() => setState(() => _f = _load());

  Future<void> _renew(LandlordListing l) async {
    try {
      await Services.landlord.renew(l.id);
      if (mounted) showMessage(context, 'Confirmed. "${l.title}" stays live for 60 more days.');
      widget.onChanged();
    } catch (_) {
      if (mounted) showMessage(context, 'Could not renew. Try again.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<(DashboardStats, List<LandlordListing>)>(
        future: _f,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (s.hasError) return ErrorState(message: 'Could not load your dashboard. Check your connection.', onRetry: _reload);
          final (st, listings) = s.data!;
          final reminders = listings.where((l) => l.needsReconfirm).toList();
          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _f;
            },
            child: ListView(padding: const EdgeInsets.all(CS.s16), children: [
              Text('Welcome back', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text('Here is your property overview.', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.7,
                children: [
                  _Stat('Total listings', st.total),
                  _Stat('Live', st.active),
                  _Stat('Total views', st.views),
                  _Stat('Enquiries', st.enquiries),
                ],
              ),
              if (st.pending > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text('${st.pending} listing${st.pending == 1 ? '' : 's'} waiting for review.', style: const TextStyle(color: CS.warn, fontWeight: FontWeight.w600)),
                ),
              const SizedBox(height: 16),
              PrimaryButton(label: 'Add new property', icon: Icons.add, color: CS.green, onPressed: widget.onAdd),
              const SizedBox(height: 16),
              for (final l in reminders)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFFFF4E0), borderRadius: BorderRadius.circular(CS.rMd)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.isExpired ? '"${l.title}" has expired' : '"${l.title}" expires in ${l.daysLeft} days', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text('Is it still available? Confirm so students keep seeing it.', style: TextStyle(fontSize: 13)),
                    const SizedBox(height: 8),
                    FilledButton(onPressed: () => _renew(l), child: const Text('Yes, still available')),
                  ]),
                ),
              _NavTile(icon: Icons.event_available_outlined, title: 'Viewing requests', subtitle: 'Confirm or decline student requests',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ViewingRequestsScreen()))),
              _NavTile(icon: Icons.home_work_outlined, title: 'My listings', subtitle: 'Edit, pause, renew or mark as rented', onTap: widget.onOpenListings),
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: CS.greenSoft, borderRadius: BorderRadius.circular(CS.rMd)),
                child: const Text('Listing on CampusStay is free. There are no listing fees and no commission.', style: TextStyle(color: CS.green, fontWeight: FontWeight.w600)),
              ),
            ]),
          );
        },
      );
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  const _Stat(this.label, this.value);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: CS.bg, borderRadius: BorderRadius.circular(CS.rMd), border: Border.all(color: CS.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text('$value', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: CS.ink)),
        ]),
      );
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _NavTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CS.rMd), side: const BorderSide(color: CS.line)),
        child: ListTile(
          leading: Icon(icon, color: CS.green),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}

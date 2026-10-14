import 'package:flutter/material.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/error_views.dart';
import '../../data/admin_models.dart';
import '../../data/repository.dart';
import '../profile/profile_screen.dart';
import 'admin_extra.dart';
import 'admin_reports.dart';
import 'admin_review.dart';

/// Admin console. Screens only call admin-only database functions; the backend
/// refuses them for anyone who is not an admin, whatever the UI shows.
class AdminHome extends StatefulWidget {
  const AdminHome({super.key});
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _tab = 0;
  int _rev = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: IndexedStack(index: _tab, children: [
            _Overview(key: ValueKey('o$_rev')),
            ReviewQueueScreen(key: ValueKey('r$_rev'), onChanged: () => setState(() => _rev++)),
            ReportsScreen(key: ValueKey('p$_rev'), onChanged: () => setState(() => _rev++)),
            LeadsScreen(key: ValueKey('l$_rev'), onChanged: () => setState(() => _rev++)),
            const ProfileScreen(),
          ]),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Overview'),
            NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check), label: 'Review'),
            NavigationDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag), label: 'Reports'),
            NavigationDestination(icon: Icon(Icons.contact_phone_outlined), selectedIcon: Icon(Icons.contact_phone), label: 'Leads'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      );
}

class _Overview extends StatefulWidget {
  const _Overview({super.key});
  @override
  State<_Overview> createState() => _OverviewState();
}

class _OverviewState extends State<_Overview> {
  late Future<AdminStats> _f = Services.admin.stats();
  void _reload() => setState(() => _f = Services.admin.stats());

  @override
  Widget build(BuildContext context) => FutureBuilder<AdminStats>(
        future: _f,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (s.hasError) return ErrorView(error: s.error!, onRetry: _reload);
          final st = s.data!;
          Widget stat(String label, int v, {bool alert = false}) => Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: CS.bg, borderRadius: BorderRadius.circular(CS.rMd), border: Border.all(color: alert && v > 0 ? CS.warn : CS.line)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text('$v', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                ]),
              );
          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _f;
            },
            child: ListView(padding: const EdgeInsets.all(CS.s16), children: [
              Text('Admin overview', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.7,
                children: [
                  stat('Awaiting review', st.pendingListings, alert: true),
                  stat('Open reports', st.openReports, alert: true),
                  stat('Documents to check', st.pendingVerifications, alert: true),
                  stat('New landlord leads', st.newLeads, alert: true),
                  stat('Live listings', st.liveListings),
                  stat('Users', st.users),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CS.rMd), side: const BorderSide(color: CS.line)),
                child: ListTile(
                  leading: const Icon(Icons.verified_user_outlined, color: CS.blue),
                  title: const Text('Verification documents', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Check IDs and proof of ownership'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VerificationScreen()));
                    if (mounted) _reload();
                  },
                ),
              ),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CS.rMd), side: const BorderSide(color: CS.line)),
                child: ListTile(
                  leading: const Icon(Icons.history, color: CS.blue),
                  title: const Text('Audit log', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Every admin action, recorded'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuditScreen())),
                ),
              ),
            ]),
          );
        },
      );
}

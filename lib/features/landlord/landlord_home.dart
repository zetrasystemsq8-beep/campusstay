import 'package:flutter/material.dart';
import '../messages/messages_screen.dart';
import '../profile/profile_screen.dart';
import '../../core/widgets/landlord_theme.dart';
import 'dashboard_screen.dart';
import 'listing_wizard.dart';
import 'listings_screen.dart';

/// Landlord / agent shell with green-accented bottom navigation.
class LandlordHome extends StatefulWidget {
  const LandlordHome({super.key});
  @override
  State<LandlordHome> createState() => _LandlordHomeState();
}

class _LandlordHomeState extends State<LandlordHome> {
  int _tab = 0;
  int _rev = 0; // bumped to reload dashboard and listings

  Future<void> _addProperty() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ListingWizard()));
    if (mounted) setState(() => _rev++);
  }

  @override
  Widget build(BuildContext context) => LandlordThemed(
        child: Scaffold(
          body: SafeArea(
            child: IndexedStack(index: _tab, children: [
              DashboardScreen(key: ValueKey('d$_rev'), onAdd: _addProperty, onOpenListings: () => setState(() => _tab = 1), onChanged: () => setState(() => _rev++)),
              ListingsScreen(key: ValueKey('l$_rev'), onAdd: _addProperty),
              const MessagesScreen(),
              const ProfileScreen(),
            ]),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.home_work_outlined), selectedIcon: Icon(Icons.home_work), label: 'Listings'),
              NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Messages'),
              NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
            ],
          ),
        ),
      );
}

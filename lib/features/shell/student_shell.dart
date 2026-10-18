import 'package:flutter/material.dart';
import '../../core/widgets/error_views.dart';
import '../../data/favourites_store.dart';
import '../../data/models.dart';
import '../explore/explore_screen.dart';
import '../explore/saved_screen.dart';
import '../home/home_screen.dart';
import '../messages/messages_screen.dart';
import '../profile/profile_screen.dart';

class StudentShell extends StatefulWidget {
  const StudentShell({super.key});
  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int _tab = 0;
  SearchFilter _filter = const SearchFilter();
  int _exploreKey = 0;

  @override
  void initState() {
    super.initState();
    FavouritesStore.loadError.addListener(_onFavError);
    FavouritesStore.load();
  }

  void _onFavError() {
    final e = FavouritesStore.loadError.value;
    if (e != null && mounted) showError(context, e, onRetry: FavouritesStore.load);
  }

  @override
  void dispose() {
    FavouritesStore.loadError.removeListener(_onFavError);
    super.dispose();
  }

  void _search(String q) => _openFilter(SearchFilter(query: q));

  void _openFilter(SearchFilter f) => setState(() {
        _filter = f;
        _exploreKey++;
        _tab = 1;
      });

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(onSearch: _search, onViewAll: () => _search(''), onOpenFilter: _openFilter),
      ExploreScreen(key: ValueKey(_exploreKey), initialFilter: _filter),
      const SavedScreen(),
      const MessagesScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _tab, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Explore'),
          NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Saved'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Messages'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

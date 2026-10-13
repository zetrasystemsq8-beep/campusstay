import 'package:flutter/material.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/buttons.dart';
import '../../data/auth_service.dart';
import '../splash/splash_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(CS.s16), children: [
        Text('Profile', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 20),
        ListTile(
          leading: const CircleAvatar(backgroundColor: CS.blueSoft, child: Icon(Icons.person, color: CS.blue)),
          title: Text(AuthService.email),
          subtitle: const Text('Signed in'),
        ),
        const SizedBox(height: 24),
        OutlineActionButton(
          icon: Icons.logout,
          label: 'Log out',
          onPressed: () async {
            await AuthService.signOut();
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const SplashScreen()), (r) => false);
            }
          },
        ),
      ]);
}

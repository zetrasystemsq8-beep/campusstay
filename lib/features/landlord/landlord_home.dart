import 'package:flutter/material.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/logo.dart';
import '../../data/auth_service.dart';
import '../splash/splash_screen.dart';

/// Stage 1 placeholder. The landlord dashboard, add-property flow, verification
/// upload and listing management are Stage 2 and are NOT implemented yet.
class LandlordHome extends StatelessWidget {
  const LandlordHome({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(CS.s24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const LogoMark(size: 72),
              const SizedBox(height: 20),
              Text('Landlord tools are coming next', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('Your account is set up as a landlord. The dashboard and listing flow are not built yet in this version.',
                  textAlign: TextAlign.center, style: TextStyle(color: CS.muted)),
              const SizedBox(height: 28),
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
            ]),
          ),
        ),
      );
}

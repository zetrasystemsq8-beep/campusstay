import 'package:flutter/material.dart';
import '../../core/config.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/logo.dart';
import '../../data/auth_service.dart';
import '../auth/auth_screen.dart';
import '../auth/role_screen.dart';
import '../shell/gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AuthService.signedIn && mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const Gate()));
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [CS.navyDeep, CS.navy, Color(0xFF123F95)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(CS.s24),
              child: Column(children: [
                const Spacer(flex: 2),
                const LogoLockup(onDark: true, size: 84),
                const SizedBox(height: 24),
                const Text('The student accommodation platform.\nFree to list. No agent fees.',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 16, height: 1.5)),
                const Spacer(flex: 3),
                if (AppConfig.devMode)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(CS.rMd)),
                    child: const Text('Development mode: sample data only. Supabase is not configured.',
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 12.5)),
                  ),
                PrimaryButton(
                  label: 'Get started',
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RoleScreen())),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const AuthScreen(role: 'student', startInSignUp: false))),
                  child: const Text('I already have an account', style: TextStyle(color: Colors.white, fontSize: 15)),
                ),
              ]),
            ),
          ),
        ),
      );
}

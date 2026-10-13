import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config.dart';
import 'core/theme/theme.dart';
import 'features/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!AppConfig.devMode) {
    await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey);
  }
  runApp(const CampusStayApp());
}

class CampusStayApp extends StatelessWidget {
  const CampusStayApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'CampusStay',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const SplashScreen(),
      );
}

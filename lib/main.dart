import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config.dart';
import 'core/errors.dart';
import 'core/theme/theme.dart';
import 'core/theme/tokens.dart';
import 'features/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Anything that escapes a screen is logged with its real cause and reference,
  // and the person sees a friendly card instead of a red error screen.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter error ${AppException(AppErrorKind.unknown, detail: details.exceptionAsString()).reference}: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught ${classify(error).reference}: $error\n$stack');
    return true;
  };
  ErrorWidget.builder = (details) => Material(
        color: CS.surface,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.build_circle_outlined, size: 40, color: CS.blue),
            const SizedBox(height: 12),
            const Text('This part tripped over its shoelaces', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: CS.ink)),
            const SizedBox(height: 6),
            Text('Go back and try again. Reference ${AppException(AppErrorKind.unknown, detail: details.exceptionAsString()).reference}.',
                textAlign: TextAlign.center, style: const TextStyle(color: CS.muted, fontSize: 13)),
          ]),
        ),
      );

  if (!AppConfig.devMode) {
    try {
      await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey).timeout(Net.normal);
    } catch (e) {
      runApp(_StartupFailure(error: classify(e)));
      return;
    }
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

/// Shown only if the backend connection cannot be set up at launch.
class _StartupFailure extends StatelessWidget {
  final AppException error;
  const _StartupFailure({required this.error});

  @override
  Widget build(BuildContext context) {
    final i = describe(error);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: CS.blue),
            const SizedBox(height: 16),
            Text(i.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('CampusStay could not start. ${i.message}', textAlign: TextAlign.center, style: const TextStyle(color: CS.muted)),
            if (i.reference != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${i.reference}: ${i.technical}', style: const TextStyle(fontSize: 12, color: CS.muted))),
            const SizedBox(height: 20),
            FilledButton(onPressed: main, child: const Text('Try again')),
          ]),
        ),
      ),
    );
  }
}

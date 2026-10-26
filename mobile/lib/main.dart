import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'screens/auth_screens.dart';
import 'screens/home_shell.dart';
import 'screens/profile_screens.dart';
import 'ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ChangeNotifierProvider(create: (_) => AppState()..init(), child: const FitHayotApp()));
}

class FitHayotApp extends StatelessWidget {
  const FitHayotApp({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return MaterialApp(
      title: 'FitHayot 360',
      debugShowCheckedModeBanner: false,
      navigatorKey: app.navigatorKey,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: app.themeMode,
      home: const RootGate(),
    );
  }
}

class RootGate extends StatelessWidget {
  const RootGate({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return switch (app.status) {
      AuthStatus.loading => SplashScreen(error: app.bootError),
      AuthStatus.onboarding => const OnboardingScreen(),
      AuthStatus.signedOut => const LoginScreen(),
      AuthStatus.needsProfile => const ProfileSetupScreen(),
      AuthStatus.ready => const MainShell(),
    };
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_info.dart';
import 'core/theme/app_theme.dart';
import 'providers/providers.dart';
import 'screens/auth/auth_gate.dart';
import 'screens/splash/splash_gate.dart';

class VaultaApp extends ConsumerWidget {
  const VaultaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      home: const SplashGate(child: AuthGate()),
    );
  }
}

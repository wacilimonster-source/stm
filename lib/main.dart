import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'presentation/providers/providers.dart';
import 'presentation/screens/welcome/welcome_screen.dart';
import 'presentation/screens/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const PocketTavernApp(),
    ),
  );
}

class PocketTavernApp extends ConsumerWidget {
  const PocketTavernApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeDataProvider);
    final connection = ref.watch(connectionProvider);

    return MaterialApp(
      title: '掌上酒馆',
      theme: theme,
      debugShowCheckedModeBanner: false,
      home: connection.status == ConnectionStatus.connected
          ? const HomeScreen()
          : const WelcomeScreen(),
    );
  }
}

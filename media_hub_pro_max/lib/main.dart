import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'core/router/app_router.dart';
import 'core/providers/app_providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  runZonedGuarded(() {
    runApp(const ProviderScope(child: GiovaPlayerApp()));
  }, (error, stack) { debugPrint('Erreur: $error'); });
}

class GiovaPlayerApp extends ConsumerWidget {
  const GiovaPlayerApp({super.key});
  static const _seeds = [0xFF6750A4, 0xFFE91E63, 0xFF2196F3, 0xFF4CAF50, 0xFFFF9800, 0xFF9C27B0, 0xFF00BCD4, 0xFFF44336, 0xFF3F51B5, 0xFF795548];
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final seed = Color(_seeds[ref.watch(themeSeedProvider) % _seeds.length]);
    return DynamicColorBuilder(builder: (lD, dD) => MaterialApp.router(
      title: 'GiovaPlayer', debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(appRouterProvider), locale: const Locale('fr', 'FR'),
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: seed, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: seed, brightness: Brightness.dark),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
    ));
  }
}

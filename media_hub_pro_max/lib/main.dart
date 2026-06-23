// GiovaPlayer v2.0 — Application multimedia 6-en-1
// Developpeur: Giova | Contact: giobamos03@gmail.com | WhatsApp: +22670698070
// Securite: aucune donnee utilisateur n'est collectee, partagee ou envoyee a un serveur.
// Toutes les donnees restent en local sur l'appareil de l'utilisateur.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'core/router/app_router.dart';
import 'core/providers/app_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  runApp(const ProviderScope(child: GiovaPlayerApp()));
}

class GiovaPlayerApp extends ConsumerWidget {
  const GiovaPlayerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final router = ref.watch(appRouterProvider);
    final seed = ref.watch(themeSeedProvider);

    return MaterialApp.router(
      title: 'GiovaPlayer',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      locale: const Locale('fr', 'FR'),
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Color(seed), brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: Color(seed), brightness: Brightness.dark),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
    );
  }
}

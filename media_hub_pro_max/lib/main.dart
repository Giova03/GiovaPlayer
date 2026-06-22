// GiovaPlayer - Application multimedia complète 6-en-1
// Contact: giobamos03@gmail.com | WhatsApp: +22670698070
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/providers/app_providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: GiovaPlayerApp()));
}

/// Point d'entrée de l'application GiovaPlayer
class GiovaPlayerApp extends ConsumerWidget {
  const GiovaPlayerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeName = ref.watch(themeNameProvider);
    final isDark = ref.watch(isDarkModeProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'GiovaPlayer',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [
        Locale('fr', 'FR'),
        Locale('en', 'US'),
      ],
      theme: _buildTheme(themeName, Brightness.light),
      darkTheme: _buildTheme(themeName, Brightness.dark),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
    );
  }

  /// Construit le thème en fonction du nom et de la luminosité
  ThemeData _buildTheme(String themeName, Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: _getSeedColor(themeName),
      brightness: brightness,
    );
  }

  /// Retourne la couleur graine selon le nom du thème
  Color _getSeedColor(String name) {
    const seeds = {
      'Violet Royal': Colors.deepPurple,
      'Bleu Ocean': Colors.blue,
      'Emeraude': Colors.green,
      'Rubis': Colors.red,
      'Ambre': Colors.amber,
      'Corail': Colors.deepOrange,
      'Lavande': Colors.purple,
      'Saphir': Colors.indigo,
      'Olive': Colors.olive,
      'Turquoise': Colors.teal,
      'Rose': Colors.pink,
      'Menthe': Color(0xFF4CAF50),
      'Cuivre': Color(0xFFB87333),
      'Ardoise': Colors.blueGrey,
      'Cramoisi': Color(0xFFDC143C),
      'Cyan': Colors.cyan,
      'Tilleul': Color(0xFFC8E6C9),
      'Indigo': Colors.indigo,
      'Or': Color(0xFFFFD700),
      'Argent': Color(0xFFC0C0C0),
    };
    return seeds[name] ?? Colors.deepPurple;
  }
}

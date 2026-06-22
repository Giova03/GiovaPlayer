import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

/// ─── POINT D'ENTRÉE MEDIA HUB PRO MAX ───
/// Architecture : Riverpod + GoRouter + Material 3 + Monet
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// Verrouillage orientation portrait pour téléphone
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  /// Barre de statut transparente
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  runApp(const ProviderScope(child: MediaHubApp()));
}

/// ─── APPLICATION RACINE ───
class MediaHubApp extends ConsumerWidget {
  const MediaHubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final isDark = ref.watch(isDarkModeProvider);
    final themeName = ref.watch(themeNameProvider);

    /// Construction du ColorScheme selon thème choisi + mode sombre
    final colorScheme = isDark
        ? AppThemes.schemeFromName(themeName, Brightness.dark)
        : AppThemes.schemeFromName(themeName, Brightness.light);

    final theme = buildTheme(colorScheme);

    return MaterialApp.router(
      title: 'Media Hub Pro MAX',
      debugShowCheckedModeBanner: false,

      /// Thème
      theme: theme,

      /// Routeur
      routerConfig: router,

      /// Locale FR par défaut
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [
        Locale('fr', 'FR'),
        Locale('en', 'US'),
      ],
    );
  }
}

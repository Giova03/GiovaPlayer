import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';

/// ─── THÈME DYNAMIQUE MONET + 20 THÈMES CUSTOM ───
/// Gestion centralisée du thème Material 3 avec support Monet

/// Palette de couleurs par défaut si Monet non disponible
const _defaultSeed = Color(0xFF6750A4);

/// Les 20 thèmes custom disponibles dans l'app
class AppThemes {
  static const Map<String, Color> themes = {
    'Violet Royal': Color(0xFF6750A4),
    'Bleu Océan': Color(0xFF1565C0),
    'Émeraude': Color(0xFF2E7D32),
    'Coucher Soleil': Color(0xFFE65100),
    'Rose Bonbon': Color(0xFFD81B60),
    'Cyan Tech': Color(0xFF00ACC1),
    'Or Luxe': Color(0xFFFFB300),
    'Ardoise': Color(0xFF455A64),
    'Corail': Color(0xFFFF6E40),
    'Menthe': Color(0xFF66BB6A),
    'Lavande': Color(0xFF9575CD),
    'Indigo Night': Color(0xFF283593),
    'Rouge Cinéma': Color(0xFFC62828),
    'Teal Pro': Color(0xFF00897B),
    'Ambre Warm': Color(0xFFFF8F00),
    'Gris Premium': Color(0xFF616161),
    'Vert Lime': Color(0xFF9E9D24),
    'Bleu Glacier': Color(0xFF4FC3F7),
    'Pêche': Color(0xFFFFAB91),
    'Noir OLED': Color(0xFF000000),
  };

  /// Retourne les couleurs du thème sélectionné
  static ColorScheme schemeFromName(String name, Brightness brightness) {
    final seed = themes[name] ?? _defaultSeed;
    return ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
  }
}

/// Construction du ThemeData complet Material 3
ThemeData buildTheme(ColorScheme colorScheme) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    brightness: colorScheme.brightness,

    /// AppBar — glassmorphism léger
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 2,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      titleTextStyle: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
    ),

    /// Cartes avec coins arrondis
    cardTheme: CardTheme(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
    ),

    /// Chips arrondis
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),

    /// FAB étendu par défaut
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primaryContainer,
      foregroundColor: colorScheme.onPrimaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),

    /// Navigation bar — style Material 3
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      backgroundColor: colorScheme.surface,
      indicatorColor: colorScheme.primaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),

    /// Bottom sheet arrondi
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      showDragHandle: true,
    ),

    /// Slider pour les contrôles audio/IA
    sliderTheme: SliderThemeData(
      activeTrackColor: colorScheme.primary,
      inactiveTrackColor: colorScheme.surfaceContainerHighest,
      thumbColor: colorScheme.primary,
      overlayColor: colorScheme.primary.withOpacity(0.12),
      trackHeight: 4,
    ),

    /// Dividers subtils
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant.withOpacity(0.5),
      thickness: 1,
    ),

    /// Typographie Optimisée
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        fontWeight: FontWeight.w700,
        letterSpacing: -1.5,
        height: 1.1,
      ),
      headlineMedium: TextStyle(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        height: 1.2,
      ),
      titleLarge: TextStyle(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      bodyLarge: const TextStyle(height: 1.5),
      bodyMedium: const TextStyle(height: 1.4),
      labelLarge: TextStyle(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
    ),
  );
}

/// Widget racine qui active le thème dynamique Monet
class DynamicThemeBuilder extends StatelessWidget {
  final Widget Function(ColorScheme) builder;

  const DynamicThemeBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        // Priorité : Monet dynamique > thème choisi > défaut
        final lightScheme = lightDynamic ??
            AppThemes.schemeFromName('Violet Royal', Brightness.light);
        final darkScheme = darkDynamic ??
            AppThemes.schemeFromName('Violet Royal', Brightness.dark);

        // On utilise le light par défaut, le dark sera géré
        // par le provider de thème
        return builder(lightScheme);
      },
    );
  }
}

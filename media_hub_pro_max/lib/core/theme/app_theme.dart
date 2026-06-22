// GiovaPlayer - Themes personnalisés avec Material 3 et DynamicColor
// Contact: giobamos03@gmail.com | WhatsApp: +22670698070
import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';

/// Classe regroupant les 20 themes de GiovaPlayer
class AppTheme {
  AppTheme._();

  /// Noms des 20 themes disponibles
  static const List<String> themeNames = [
    'Violet Royal', 'Bleu Ocean', 'Emeraude', 'Rubis', 'Ambre',
    'Corail', 'Lavande', 'Saphir', 'Olive', 'Turquoise',
    'Rose', 'Menthe', 'Cuivre', 'Ardoise', 'Cramoisi',
    'Cyan', 'Tilleul', 'Indigo', 'Or', 'Argent',
  ];

  /// Couleurs graines pour chaque theme
  static const List<Color> seedColors = [
    Color(0xFF7B1FA2), Color(0xFF1565C0), Color(0xFF2E7D32),
    Color(0xFFC62828), Color(0xFFFF8F00), Color(0xFFD84315),
    Color(0xFF9C27B0), Color(0xFF283593), Color(0xFF827717),
    Color(0xFF00897B), Color(0xFFE91E63), Color(0xFF66BB6A),
    Color(0xFFB87333), Color(0xFF546E7A), Color(0xFFDC143C),
    Color(0xFF00BCD4), Color(0xFFCDDC39), Color(0xFF3F51B5),
    Color(0xFFFFD700), Color(0xFFC0C0C0),
  ];

  /// Retourne la couleur graine par nom de theme
  static Color getSeedColor(String name) {
    final idx = themeNames.indexOf(name);
    return idx >= 0 ? seedColors[idx] : seedColors[0];
  }

  /// Construit le ThemeData complet pour un theme donne
  static ThemeData buildTheme({
    required String themeName,
    required bool isDark,
    ColorScheme? dynamicColorScheme,
  }) {
    final seedColor = getSeedColor(themeName);
    final brightness = isDark ? Brightness.dark : Brightness.light;

    final colorScheme = dynamicColorScheme ??
        ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
      appBarTheme: _buildAppBarTheme(colorScheme),
      cardTheme: _buildCardTheme(colorScheme),
      navigationBarTheme: _buildNavBarTheme(colorScheme),
      sliderTheme: _buildSliderTheme(colorScheme),
      textTheme: _buildTextTheme(),
    );
  }

  /// Theme de l'AppBar
  static AppBarTheme _buildAppBarTheme(ColorScheme cs) {
    return AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 2,
      backgroundColor: cs.surface,
      foregroundColor: cs.onSurface,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: cs.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  /// Theme des cartes - utilise CardThemeData (pas CardTheme)
  static CardThemeData _buildCardTheme(ColorScheme cs) {
    return CardThemeData(
      elevation: 1,
      shadowColor: cs.shadow.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      color: cs.surfaceContainerLow,
      surfaceTintColor: cs.surfaceTint,
    );
  }

  /// Theme de la barre de navigation
  static NavigationBarThemeData _buildNavBarTheme(ColorScheme cs) {
    return NavigationBarThemeData(
      elevation: 3,
      backgroundColor: cs.surface,
      indicatorColor: cs.primaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: cs.onPrimaryContainer, size: 24);
        }
        return IconThemeData(color: cs.onSurfaceVariant, size: 22);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(
            color: cs.onPrimaryContainer,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          );
        }
        return TextStyle(color: cs.onSurfaceVariant, fontSize: 11);
      }),
    );
  }

  /// Theme du slider
  static SliderThemeData _buildSliderTheme(ColorScheme cs) {
    return SliderThemeData(
      activeTrackColor: cs.primary,
      inactiveTrackColor: cs.surfaceContainerHighest,
      thumbColor: cs.primary,
      overlayColor: cs.primary.withValues(alpha: 0.12),
      trackHeight: 4,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
    );
  }

  /// Texte par defaut de l'application
  static TextTheme _buildTextTheme() {
    return const TextTheme(
      headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
    );
  }
}

/// Widget wrapper pour activer les couleurs dynamiques Android
class DynamicThemeWrapper extends StatelessWidget {
  final Widget child;
  final String themeName;
  final bool isDark;

  const DynamicThemeWrapper({
    super.key,
    required this.child,
    required this.themeName,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final dynamicCs = isDark ? darkDynamic : lightDynamic;
        final theme = AppTheme.buildTheme(
          themeName: themeName,
          isDark: isDark,
          dynamicColorScheme: dynamicCs,
        );
        return Theme(data: theme, child: child);
      },
    );
  }
}

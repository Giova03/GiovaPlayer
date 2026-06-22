// GiovaPlayer - Routeur principal avec GoRouter et ShellRoute
// Contact: giobamos03@gmail.com | WhatsApp: +22670698070
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/app_providers.dart';
import '../../features/audio/screens/audio_player_screen.dart';
import '../../features/video/screens/video_player_screen.dart';
import '../../features/gallery/screens/gallery_screen.dart';
import '../../features/vault/screens/vault_screen.dart';
import '../../features/downloader/screens/downloader_screen.dart';
import '../../features/tools/screens/tools_screen.dart';

/// Provider du routeur GiovaPlayer
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/accueil',
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return _ScaffoldWithNavBar(child: child);
        },
        routes: [
          GoRoute(
            path: '/accueil',
            builder: (context, state) => const _HomeDashboard(),
          ),
          GoRoute(
            path: '/audio',
            builder: (context, state) => const AudioPlayerScreen(),
          ),
          GoRoute(
            path: '/video',
            builder: (context, state) => const VideoPlayerScreen(),
          ),
          GoRoute(
            path: '/galerie',
            builder: (context, state) => const GalleryScreen(),
          ),
          GoRoute(
            path: '/coffre',
            builder: (context, state) => const VaultScreen(),
          ),
          GoRoute(
            path: '/download',
            builder: (context, state) => const DownloaderScreen(),
          ),
          GoRoute(
            path: '/outils',
            builder: (context, state) => const ToolsScreen(),
          ),
        ],
      ),
    ],
  );
});

/// Onglets de navigation principaux
class _NavItem {
  final String path;
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _NavItem({
    required this.path,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

/// Liste des 7 onglets de navigation
const _navItems = [
  _NavItem(path: '/accueil', label: 'Accueil', icon: Icons.home_outlined, activeIcon: Icons.home),
  _NavItem(path: '/audio', label: 'Audio', icon: Icons.music_note_outlined, activeIcon: Icons.music_note),
  _NavItem(path: '/video', label: 'Video', icon: Icons.play_circle_outline, activeIcon: Icons.play_circle),
  _NavItem(path: '/galerie', label: 'Galerie', icon: Icons.photo_library_outlined, activeIcon: Icons.photo_library),
  _NavItem(path: '/coffre', label: 'Coffre', icon: Icons.lock_outline, activeIcon: Icons.lock),
  _NavItem(path: '/download', label: 'Download', icon: Icons.download_outlined, activeIcon: Icons.download),
  _NavItem(path: '/outils', label: 'Outils', icon: Icons.build_outlined, activeIcon: Icons.build),
];

/// Scaffold principal avec la barre de navigation inferieure
class _ScaffoldWithNavBar extends StatelessWidget {
  final Widget child;
  const _ScaffoldWithNavBar({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        destinations: _navItems
            .map((n) => NavigationDestination(
                  icon: Icon(n.icon),
                  selectedIcon: Icon(n.activeIcon),
                  label: n.label,
                ))
            .toList(),
        onDestinationSelected: (idx) => context.go(_navItems[idx].path),
        selectedIndex: _currentIndex(context),
      ),
    );
  }

  /// Calcule l'index de l'onglet actif
  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (var i = 0; i < _navItems.length; i++) {
      if (location.startsWith(_navItems[i].path)) return i;
    }
    return 0;
  }
}

/// Tableau de bord principal avec branding GiovaPlayer
class _HomeDashboard extends ConsumerWidget {
  const _HomeDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('GiovaPlayer')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBrandingCard(cs, theme),
            const SizedBox(height: 20),
            _buildModuleGrid(context, cs),
            const SizedBox(height: 20),
            _buildIaSuggestions(cs),
          ],
        ),
      ),
    );
  }

  /// Carte de branding GiovaPlayer
  Widget _buildBrandingCard(ColorScheme cs, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.play_circle_filled, size: 56, color: cs.primary),
            const SizedBox(height: 12),
            Text('GiovaPlayer', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              '6 applications en 1',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'giobamos03@gmail.com | WhatsApp: +22670698070',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Grille des modules principaux
  Widget _buildModuleGrid(BuildContext context, ColorScheme cs) {
    final modules = [
      _ModuleItem(Icons.music_note, 'Audio', '/audio'),
      _ModuleItem(Icons.play_circle, 'Video', '/video'),
      _ModuleItem(Icons.photo_library, 'Galerie', '/galerie'),
      _ModuleItem(Icons.lock, 'Coffre', '/coffre'),
      _ModuleItem(Icons.download, 'Download', '/download'),
      _ModuleItem(Icons.build, 'Outils', '/outils'),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: modules.map((m) {
        return Card(
          child: InkWell(
            onTap: () => context.go(m.route),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(m.icon, size: 32, color: cs.primary),
                  const SizedBox(height: 8),
                  Text(m.label, style: Theme.of(context).textTheme.labelLarge),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Suggestions IA sur le tableau de bord
  Widget _buildIaSuggestions(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Suggestions IA', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: Icon(Icons.auto_fix_high, color: cs.primary),
            title: const Text('Amelioration photo IA'),
            subtitle: const Text('Optimisez vos photos automatiquement'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/galerie'),
          ),
        ),
        Card(
          child: ListTile(
            leading: Icon(Icons.subtitles, color: cs.primary),
            title: const Text('Sous-titres IA'),
            subtitle: const Text('Generer des sous-titres pour vos videos'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/video'),
          ),
        ),
      ],
    );
  }
}

/// Element de module pour la grille d'accueil
class _ModuleItem {
  final IconData icon;
  final String label;
  final String route;
  const _ModuleItem(this.icon, this.label, this.route);
}

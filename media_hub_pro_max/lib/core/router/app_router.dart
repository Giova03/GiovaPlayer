import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/audio/screens/audio_player_screen.dart';
import '../../features/video/screens/video_player_screen.dart';
import '../../features/gallery/screens/gallery_screen.dart';
import '../../features/ia_photo/screens/ia_photo_fix_screen.dart';
import '../../features/vault/screens/vault_screen.dart';
import '../../features/downloader/screens/downloader_screen.dart';
import '../../features/tools/screens/tools_screen.dart';
import '../theme/app_theme.dart';

/// ─── PROVIDER DU THÈME SÉLECTIONNÉ ───
final themeNameProvider = StateProvider<String>((ref) => 'Violet Royal');
final isDarkModeProvider = StateProvider<bool>((ref) => true);

/// ─── ROUTEUR PRINCIPAL GO_ROUTER ───
/// Navigation déclarative avec transitions fluides
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    routes: [
      /// Route racine = écran d'accueil avec NavigationBar
      ShellRoute(
        builder: (context, state, child) {
          return MainScaffold(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            builder: (context, state) => const _HomeDashboard(),
          ),
          GoRoute(
            path: '/audio',
            name: 'audio',
            builder: (context, state) => const AudioPlayerScreen(),
          ),
          GoRoute(
            path: '/video',
            name: 'video',
            builder: (context, state) => const VideoPlayerScreen(),
          ),
          GoRoute(
            path: '/gallery',
            name: 'gallery',
            builder: (context, state) => const GalleryScreen(),
          ),
          GoRoute(
            path: '/vault',
            name: 'vault',
            builder: (context, state) => const VaultScreen(),
          ),
          GoRoute(
            path: '/downloader',
            name: 'downloader',
            builder: (context, state) => const DownloaderScreen(),
          ),
          GoRoute(
            path: '/tools',
            name: 'tools',
            builder: (context, state) => const ToolsScreen(),
          ),
        ],
      ),

      /// Routes hors Shell (plein écran)
      GoRoute(
        path: '/ia-photo-fix',
        name: 'iaPhotoFix',
        builder: (context, state) => const IaPhotoFixScreen(),
      ),
    ],
  );
});

/// ─── SQUELETTE PRINCIPAL AVEC NAVIGATION BAR ───
class MainScaffold extends ConsumerWidget {
  final Widget child;
  const MainScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    /// Index actif basé sur la route
    final location = GoRouterState.of(context).uri.path;
    final currentIndex = switch (location) {
      '/' => 0,
      '/audio' => 1,
      '/video' => 2,
      '/gallery' => 3,
      '/vault' => 4,
      '/downloader' => 5,
      '/tools' => 6,
      _ => 0,
    };

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          final target = switch (index) {
            0 => '/',
            1 => '/audio',
            2 => '/video',
            3 => '/gallery',
            4 => '/vault',
            5 => '/downloader',
            6 => '/tools',
            _ => '/',
          };
          context.go(target);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.headphones_outlined),
            selectedIcon: Icon(Icons.headphones),
            label: 'Audio',
          ),
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            selectedIcon: Icon(Icons.play_circle),
            label: 'Vidéo',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library),
            label: 'Galerie',
          ),
          NavigationDestination(
            icon: Icon(Icons.lock_outline),
            selectedIcon: Icon(Icons.lock),
            label: 'Coffre',
          ),
          NavigationDestination(
            icon: Icon(Icons.download_outlined),
            selectedIcon: Icon(Icons.download),
            label: 'Download',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build),
            label: 'Outils',
          ),
        ],
      ),
    );
  }
}

/// ─── ÉCRAN D'ACCUEIL DASHBOARD ───
class _HomeDashboard extends ConsumerWidget {
  const _HomeDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Hub Pro MAX'),
        actions: [
          /// Bascule thème clair/sombre
          IconButton(
            icon: Icon(
              ref.watch(isDarkModeProvider)
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () => ref.read(isDarkModeProvider.notifier).state =
                !ref.read(isDarkModeProvider),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          /// Carte bienvenue IA
          _WelcomeCard(),
          const SizedBox(height: 16),

          /// Grille des 6 modules
          Text(
            'Modules',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _ModuleGrid(),
          const SizedBox(height: 24),

          /// Suggestions IA
          Text(
            'Suggestions IA',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _AiSuggestions(),
        ],
      ),
    );
  }
}

/// Carte bienvenue avec animation Rive placeholder
class _WelcomeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: cs.onPrimaryContainer, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Bienvenue dans Media Hub Pro MAX',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: cs.onPrimaryContainer,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '6 apps en 1. Audio Hi-Res, Vidéo 8K, Galerie IA, '
              'Coffre-fort AES-256, Downloader universel, Outils pro.',
              style: TextStyle(color: cs.onPrimaryContainer.withOpacity(0.8)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grille des 6 modules principaux
class _ModuleGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final modules = [
      _ModuleItem('Audio', Icons.headphones, '/audio', 'Hi-Res FLAC/WAV/DSF'),
      _ModuleItem('Vidéo', Icons.play_circle, '/video', '8K HDR10+ Dolby'),
      _ModuleItem('Galerie', Icons.photo_library, '/gallery', 'Tri IA + Recherche'),
      _ModuleItem('Coffre', Icons.lock, '/vault', 'AES-256 + Biométrie'),
      _ModuleItem('Download', Icons.download, '/downloader', 'YT/TikTok/Torrent'),
      _ModuleItem('Outils', Icons.build, '/tools', 'Convertisseur + Clean'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: modules.length,
      itemBuilder: (context, index) => modules[index],
    );
  }
}

class _ModuleItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final String route;
  final String subtitle;

  const _ModuleItem(this.title, this.icon, this.route, this.subtitle);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: () => context.go(route),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: cs.primary),
              const SizedBox(height: 8),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Suggestions IA basées sur l'usage
class _AiSuggestions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.auto_fix_high),
          title: const Text('Correction Photo IA'),
          subtitle: const Text('3 photos nécessitent une correction auto'),
          trailing: const Icon(Icons.arrow_forward),
          onTap: () => context.push('/ia-photo-fix'),
        ),
        ListTile(
          leading: const Icon(Icons.delete_sweep),
          title: const Text('Nettoyage suggéré'),
          subtitle: const Text('1.2 GB de fichiers doublons détectés'),
          trailing: const Icon(Icons.arrow_forward),
          onTap: () => context.go('/tools'),
        ),
      ],
    );
  }
}

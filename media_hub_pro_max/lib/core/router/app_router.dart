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
import '../providers/app_providers.dart';

final appRouterProvider = Provider<GoRouter>((ref) => GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(builder: (c, s, child) => _Shell(child: child), routes: [
      GoRoute(path: '/', builder: (_, __) => const _Home()),
      GoRoute(path: '/audio', builder: (_, __) => const AudioPlayerScreen()),
      GoRoute(path: '/video', builder: (_, __) => const VideoPlayerScreen()),
      GoRoute(path: '/gallery', builder: (_, __) => const GalleryScreen()),
      GoRoute(path: '/vault', builder: (_, __) => const VaultScreen()),
      GoRoute(path: '/downloader', builder: (_, __) => const DownloaderScreen()),
      GoRoute(path: '/tools', builder: (_, __) => const ToolsScreen()),
    ]),
    GoRoute(path: '/ia-photo', builder: (_, __) => const IaPhotoFixScreen()),
  ],
));

class _Shell extends ConsumerWidget {
  final Widget child;
  const _Shell({required this.child});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = GoRouterState.of(context).uri.path;
    final idx = switch (loc) {
      '/' => 0, '/audio' => 1, '/video' => 2, '/gallery' => 3,
      '/vault' => 4, '/downloader' => 5, '/tools' => 6, _ => 0,
    };
    return Scaffold(body: child, bottomNavigationBar: NavigationBar(
      selectedIndex: idx,
      onDestinationSelected: (i) => context.go(switch(i){0=>'/',1=>'/audio',2=>'/video',3=>'/gallery',4=>'/vault',5=>'/downloader',6=>'/tools',_=>'/'}),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Accueil'),
        NavigationDestination(icon: Icon(Icons.headphones_outlined), selectedIcon: Icon(Icons.headphones), label: 'Audio'),
        NavigationDestination(icon: Icon(Icons.play_circle_outline), selectedIcon: Icon(Icons.play_circle), label: 'Video'),
        NavigationDestination(icon: Icon(Icons.photo_library_outlined), selectedIcon: Icon(Icons.photo_library), label: 'Galerie'),
        NavigationDestination(icon: Icon(Icons.lock_outline), selectedIcon: Icon(Icons.lock), label: 'Coffre'),
        NavigationDestination(icon: Icon(Icons.download_outlined), selectedIcon: Icon(Icons.download), label: 'Download'),
        NavigationDestination(icon: Icon(Icons.build_outlined), selectedIcon: Icon(Icons.build), label: 'Outils'),
      ],
    ));
  }
}

class _Home extends ConsumerWidget {
  const _Home();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(appBar: AppBar(title: const Text('GiovaPlayer'), actions: [
      IconButton(icon: Icon(ref.watch(isDarkModeProvider) ? Icons.light_mode : Icons.dark_mode),
        onPressed: () => ref.read(isDarkModeProvider.notifier).state = !ref.read(isDarkModeProvider)),
    ]), body: ListView(padding: const EdgeInsets.all(16), children: [
      Card(color: cs.primaryContainer, child: Padding(padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.auto_awesome, color: cs.onPrimaryContainer), const SizedBox(width: 12),
            Expanded(child: Text('GiovaPlayer v2.0', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.onPrimaryContainer)))]),
          const SizedBox(height: 8),
          Text('6 apps en 1 • 100% offline • Vos donnees restent sur votre appareil',
            style: TextStyle(color: cs.onPrimaryContainer.withValues(alpha:0.8), fontSize: 13)),
          const SizedBox(height: 4),
          Text('Contact: giobamos03@gmail.com | WhatsApp: +22670698070',
            style: TextStyle(color: cs.onPrimaryContainer.withValues(alpha:0.6), fontSize: 11)),
        ]))),
      const SizedBox(height: 24),
      Text('Modules', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.5,
        children: [
          _Mod('Audio', Icons.headphones, '/audio', 'Hi-Res FLAC/DSF', cs),
          _Mod('Video', Icons.play_circle, '/video', '8K HDR10+ Dolby', cs),
          _Mod('Galerie', Icons.photo_library, '/gallery', 'Tri IA + Edition', cs),
          _Mod('Coffre', Icons.lock, '/vault', 'AES-256 + PIN', cs),
          _Mod('Download', Icons.download, '/downloader', 'YT/TikTok/Torrent', cs),
          _Mod('Outils', Icons.build, '/tools', 'Convertisseur+Clean', cs),
        ]),
      const SizedBox(height: 24),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.security, color: cs.tertiary), const SizedBox(width: 12),
          Expanded(child: Text('Protection des donnees', style: Theme.of(context).textTheme.titleSmall))]),
        const SizedBox(height: 8),
        const Text('- Aucune donnee collectee ou envoyee a un serveur', style: TextStyle(fontSize: 12)),
        const Text('- Toutes les donnees restent sur votre appareil', style: TextStyle(fontSize: 12)),
        const Text('- Chiffrement AES-256 pour le coffre-fort', style: TextStyle(fontSize: 12)),
        const Text('- Aucun analytics, aucun tracking', style: TextStyle(fontSize: 12)),
        const Text('- Permissions demandees uniquement si necessaire', style: TextStyle(fontSize: 12)),
        const Text('- Droit de suppression totale des donnees', style: TextStyle(fontSize: 12)),
      ]))),
    ]));
  }
}

class _Mod extends StatelessWidget {
  final String t; final IconData i; final String r; final String s; final ColorScheme cs;
  const _Mod(this.t, this.i, this.r, this.s, this.cs);
  @override
  Widget build(BuildContext context) => Card(child: InkWell(onTap: () => context.go(r),
    borderRadius: BorderRadius.circular(16),
    child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(i, size: 32, color: cs.primary), const SizedBox(height: 8),
      Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 2), Text(s, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
    ]))));
}

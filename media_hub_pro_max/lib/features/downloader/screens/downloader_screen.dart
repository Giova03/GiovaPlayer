import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ─── ÉCRAN DOWNLOADER UNIVERSEL ───
/// Features: YouTube/TikTok/IG/FB/Twitter 4K/MP3,
/// Torrent + reprise + limite vitesse, Colle lien = analyse auto
class DownloaderScreen extends ConsumerStatefulWidget {
  const DownloaderScreen({super.key});

  @override
  ConsumerState<DownloaderScreen> createState() => _DownloaderScreenState();
}

class _DownloaderScreenState extends ConsumerState<DownloaderScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _urlController = TextEditingController();
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloader'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showDownloadSettings,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Nouveau'),
            Tab(text: 'En cours'),
            Tab(text: 'Terminés'),
          ],
        ),
      ),
      body: Column(
        children: [
          /// Barre URL — colle lien = analyse auto
          _UrlBar(
            controller: _urlController,
            isAnalyzing: _isAnalyzing,
            onAnalyze: _analyzeUrl,
            onPaste: _pasteFromClipboard,
          ),

          /// Contenu des onglets
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _NewDownloadTab(),
                _ActiveDownloadsTab(),
                _CompletedDownloadsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Analyse automatique de l'URL collée
  Future<void> _analyzeUrl() async {
    if (_urlController.text.isEmpty) return;

    setState(() => _isAnalyzing = true);

    try {
      final url = _urlController.text;

      /// En production : youtube_explode_dart / yt-dlp
      /// Détecter plateforme + formats disponibles
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        _showFormatSelector(url);
      }
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  /// Affiche les formats disponibles pour l'URL
  void _showFormatSelector(String url) {
    final platform = _detectPlatform(url);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Icon(platform.icon, size: 32, color: platform.color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(platform.name, style: Theme.of(context).textTheme.titleMedium),
                      Text('Détecté automatiquement',
                          style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            /// Titre de la vidéo
            Text('Titre du contenu détecté',
                style: Theme.of(context).textTheme.titleSmall),
            Text('Durée: 12:34 • Vues: 1.2M',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),

            /// Formats vidéo
            Text('Vidéo', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _FormatTile('4K (2160p)', 'MP4 • H.265 • ~2.5 GB', true),
            _FormatTile('1440p', 'MP4 • H.264 • ~1.2 GB', false),
            _FormatTile('1080p', 'MP4 • H.264 • ~600 MB', false),
            _FormatTile('720p', 'MP4 • H.264 • ~300 MB', false),
            _FormatTile('480p', 'MP4 • H.264 • ~150 MB', false),

            const SizedBox(height: 16),

            /// Formats audio
            Text('Audio', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _FormatTile('FLAC', 'Lossless • ~45 MB', false),
            _FormatTile('MP3 320kbps', 'Haute qualité • ~12 MB', false),
            _FormatTile('M4A 256kbps', 'AAC • ~10 MB', false),
            _FormatTile('OPUS 128kbps', 'Compact • ~6 MB', false),

            const SizedBox(height: 24),

            /// Bouton télécharger
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _startDownload(url, '4K MP4');
                },
                icon: const Icon(Icons.download),
                label: const Text('Télécharger'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Détection plateforme depuis URL
  _PlatformInfo _detectPlatform(String url) {
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      return _PlatformInfo('YouTube', Icons.play_circle, Colors.red);
    } else if (url.contains('tiktok.com')) {
      return _PlatformInfo('TikTok', Icons.music_note, Colors.pink);
    } else if (url.contains('instagram.com')) {
      return _PlatformInfo('Instagram', Icons.camera, Colors.purple);
    } else if (url.contains('facebook.com') || url.contains('fb.')) {
      return _PlatformInfo('Facebook', Icons.thumb_up, Colors.blue);
    } else if (url.contains('twitter.com') || url.contains('x.com')) {
      return _PlatformInfo('Twitter/X', Icons.flutter_dash, Colors.cyan);
    }
    return _PlatformInfo('Web', Icons.language, Colors.grey);
  }

  void _startDownload(String url, String format) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Téléchargement $format démarré')),
    );
  }

  void _pasteFromClipboard() {
    /// En production : Clipboard.getData('text/plain')
  }

  void _showDownloadSettings() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView(
        padding: const EdgeInsets.all(24),
        shrinkWrap: true,
        children: [
          Text('Paramètres Download',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Dossier de téléchargement'),
            subtitle: const Text('/storage/emulated/0/Download/MediaHub'),
            trailing: const Icon(Icons.folder),
            onTap: () {},
          ),
          SwitchListTile(
            title: const Text('WiFi uniquement'),
            subtitle: const Text('Pas de téléchargement en 4G'),
            value: true,
            onChanged: (_) {},
          ),
          SwitchListTile(
            title: const Text('Limite vitesse horaire'),
            subtitle: const Text('Réduire vitesse en heures pleines'),
            value: false,
            onChanged: (_) {},
          ),
          ListTile(
            title: const Text('Vitesse max'),
            subtitle: const Text('Illimitée'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

/// ─── BARRE URL ───
class _UrlBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isAnalyzing;
  final VoidCallback onAnalyze;
  final VoidCallback onPaste;

  const _UrlBar({
    required this.controller,
    required this.isAnalyzing,
    required this.onAnalyze,
    required this.onPaste,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: 'Collez un lien YouTube, TikTok, IG, FB, Twitter...',
          prefixIcon: isAnalyzing
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : const Icon(Icons.link),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.content_paste),
                onPressed: onPaste,
                tooltip: 'Coller',
              ),
              IconButton(
                icon: const Icon(Icons.analyze),
                onPressed: onAnalyze,
                tooltip: 'Analyser',
              ),
            ],
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        onSubmitted: (_) => onAnalyze(),
      ),
    );
  }
}

/// ─── ONGLET NOUVEAU DOWNLOAD ───
class _NewDownloadTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        /// Plateformes supportées
        Text('Plateformes', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(avatar: const Icon(Icons.play_circle, size: 16), label: const Text('YouTube')),
            Chip(avatar: const Icon(Icons.music_note, size: 16), label: const Text('TikTok')),
            Chip(avatar: const Icon(Icons.camera, size: 16), label: const Text('Instagram')),
            Chip(avatar: const Icon(Icons.thumb_up, size: 16), label: const Text('Facebook')),
            Chip(avatar: const Icon(Icons.flutter_dash, size: 16), label: const Text('Twitter/X')),
          ],
        ),
        const SizedBox(height: 24),

        /// Torrent
        Card(
          child: ListTile(
            leading: Icon(Icons.download, color: cs.primary),
            title: const Text('Téléchargement Torrent'),
            subtitle: const Text('Fichier .torrent ou lien magnétique'),
            trailing: const Icon(Icons.add),
            onTap: () {
              /// Ouvrir sélecteur .torrent
            },
          ),
        ),
        const SizedBox(height: 16),

        /// Historique collé
        Text('Récemment analysés',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...List.generate(3, (i) => ListTile(
          leading: const Icon(Icons.history),
          title: Text('Vidéo ${i + 1} — https://youtube.com/...'),
          subtitle: Text('Il y a ${[2, 5, 24][i]} heures'),
          trailing: const Icon(Icons.download),
          onTap: () {},
        )),
      ],
    );
  }
}

/// ─── ONGLET TÉLÉCHARGEMENTS ACTIFS ───
class _ActiveDownloadsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _DownloadProgressTile(
          title: 'Film_4K_HDR.mkv',
          platform: 'YouTube',
          progress: 0.67,
          speed: '12.4 MB/s',
          size: '1.8 / 2.5 GB',
        ),
        _DownloadProgressTile(
          title: 'Musique_album.flac',
          platform: 'YouTube',
          progress: 0.35,
          speed: '3.2 MB/s',
          size: '15 / 45 MB',
        ),
        _DownloadProgressTile(
          title: 'Clip_tiktok.mp4',
          platform: 'TikTok',
          progress: 0.92,
          speed: '8.1 MB/s',
          size: '27 / 30 MB',
        ),
      ],
    );
  }
}

class _DownloadProgressTile extends StatelessWidget {
  final String title;
  final String platform;
  final double progress;
  final String speed;
  final String size;

  const _DownloadProgressTile({
    required this.title,
    required this.platform,
    required this.progress,
    required this.speed,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: Theme.of(context).textTheme.bodyLarge),
                ),
                Text(speed, style: TextStyle(
                  color: cs.primary, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 4),
            Text('$platform • $size',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${(progress * 100).round()}%',
                    style: TextStyle(fontSize: 12, color: cs.primary)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.pause, size: 18),
                      onPressed: () {},
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, size: 18),
                      onPressed: () {},
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ─── ONGLET TÉLÉCHARGEMENTS TERMINÉS ───
class _CompletedDownloadsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        /// Stats
        Row(
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text('47', style: Theme.of(context).textTheme.headlineSmall),
                      Text('Fichiers', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text('18.5 GB', style: Theme.of(context).textTheme.headlineSmall),
                      Text('Total', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        /// Fichiers terminés
        ...List.generate(8, (i) => ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              i % 3 == 0 ? Icons.movie : i % 3 == 1 ? Icons.music_note : Icons.image,
              color: cs.onSurfaceVariant,
            ),
          ),
          title: Text('Fichier_téléchargé_${i + 1}'),
          subtitle: Text('${[2.5, 0.5, 0.045, 1.2, 0.8, 0.3, 5.1, 0.1][i]} GB • ${['MP4', 'MP4', 'FLAC', 'MKV', 'MP4', 'MP3', 'MKV', 'JPG'][i]}'),
          trailing: PopupMenuButton(
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'open', child: Text('Ouvrir')),
              const PopupMenuItem(value: 'share', child: Text('Partager')),
              const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
            ],
          ),
        )),
      ],
    );
  }
}

/// ─── TUile FORMAT ───
class _FormatTile extends StatelessWidget {
  final String quality;
  final String details;
  final bool isSelected;

  const _FormatTile(this.quality, this.details, this.isSelected);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: isSelected ? cs.primaryContainer : null,
      child: ListTile(
        dense: true,
        title: Text(quality, style: TextStyle(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
        )),
        subtitle: Text(details, style: TextStyle(fontSize: 12)),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: cs.primary)
            : const Icon(Icons.radio_button_unchecked),
        onTap: () {},
      ),
    );
  }
}

/// ─── INFO PLATEFORME ───
class _PlatformInfo {
  final String name;
  final IconData icon;
  final Color color;

  const _PlatformInfo(this.name, this.icon, this.color);
}

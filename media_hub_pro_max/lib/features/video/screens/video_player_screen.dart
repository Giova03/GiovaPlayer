import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ─── ÉCRAN LECTEUR VIDÉO 8K HDR10+ ───
/// Features: 8K/HDR10+/Dolby Vision, Sous-titres IA, VR 360°,
/// Découpe/Fusion, Extracteur, Mode Kids
class VideoPlayerScreen extends ConsumerStatefulWidget {
  const VideoPlayerScreen({super.key});

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  bool _isPlaying = false;
  double _progress = 0.0;
  bool _isKidsMode = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vidéo Pro'),
        actions: [
          /// Mode VR 360°
          IconButton(
            icon: const Icon(Icons.threed_rotation),
            onPressed: _showVrOptions,
            tooltip: 'VR 360°',
          ),
          /// Mode Kids
          IconButton(
            icon: Icon(
              _isKidsMode ? Icons.child_care : Icons.child_care_outlined,
            ),
            onPressed: () => setState(() => _isKidsMode = !_isKidsMode),
            tooltip: 'Mode Kids',
          ),
          /// Outils vidéo
          IconButton(
            icon: const Icon(Icons.movie_edit),
            onPressed: _showVideoTools,
            tooltip: 'Outils vidéo',
          ),
        ],
      ),
      body: _isKidsMode ? const _KidsModeView() : _PlayerView(
        isPlaying: _isPlaying,
        progress: _progress,
        onPlayPause: () => setState(() => _isPlaying = !_isPlaying),
        onProgressChanged: (v) => setState(() => _progress = v),
      ),
    );
  }

  /// Options VR 360° + gyroscope
  void _showVrOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView(
        padding: const EdgeInsets.all(24),
        shrinkWrap: true,
        children: [
          Text('Mode VR 360°', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Vue 360°'),
            subtitle: const Text('Rotation libre avec gyroscope'),
            value: false,
            onChanged: (_) {},
          ),
          SwitchListTile(
            title: const Text('Split écran VR'),
            subtitle: const Text('Pour casques Cardboard/Gear VR'),
            value: false,
            onChanged: (_) {},
          ),
          SwitchListTile(
            title: const Text('Gyroscope actif'),
            subtitle: const Text('Inclinaison du téléphone = rotation'),
            value: false,
            onChanged: (_) {},
          ),
        ],
      ),
    );
  }

  /// Outils vidéo : découpe, fusion, extracteur, compresseur
  void _showVideoTools() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          children: [
            Text('Outils Vidéo', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _VideoToolCard(
              icon: Icons.content_cut,
              title: 'Découpe sans perte',
              subtitle: 'Coupez des segments sans ré-encoder',
              onTap: () {},
            ),
            _VideoToolCard(
              icon: Icons.merge,
              title: 'Fusion vidéos',
              subtitle: 'Assemblez plusieurs clips en un',
              onTap: () {},
            ),
            _VideoToolCard(
              icon: Icons.branding_watermark,
              title: 'Ajouter filigrane',
              subtitle: 'Logo ou texte personnalisé',
              onTap: () {},
            ),
            _VideoToolCard(
              icon: Icons.subtitles,
              title: 'Extracteur sous-titres',
              subtitle: 'Extraire SRT/ASS d\'une vidéo',
              onTap: () {},
            ),
            _VideoToolCard(
              icon: Icons.audiotrack,
              title: 'Extracteur audio',
              subtitle: 'Convertir vidéo → MP3/FLAC',
              onTap: () {},
            ),
            _VideoToolCard(
              icon: Icons.compress,
              title: 'Compresseur H.265',
              subtitle: 'Réduire taille sans perte visible',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

/// ─── VUE LECTEUR PRINCIPAL ───
class _PlayerView extends StatelessWidget {
  final bool isPlaying;
  final double progress;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onProgressChanged;

  const _PlayerView({
    required this.isPlaying,
    required this.progress,
    required this.onPlayPause,
    required this.onProgressChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        /// Zone vidéo — en paysage si rotation activée
        Expanded(
          flex: 3,
          child: Container(
            color: Colors.black,
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  /// Placeholder vidéo
                  const Icon(Icons.play_circle_outline,
                      size: 80, color: Colors.white54),

                  /// Indicateur HDR
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'HDR10+ • 8K',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),

                  /// Contrôles overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black87],
                        ),
                      ),
                      child: Column(
                        children: [
                          /// Barre de progression
                          SliderTheme(
                            data: SliderThemeData(
                              thumbColor: Colors.red,
                              activeTrackColor: Colors.red,
                            ),
                            child: Slider(
                              value: progress,
                              onChanged: onProgressChanged,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('12:34', style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.subtitles,
                                        color: Colors.white70, size: 20),
                                    onPressed: () => _showSubtitleOptions(context),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      isPlaying ? Icons.pause : Icons.play_arrow,
                                      color: Colors.white,
                                    ),
                                    onPressed: onPlayPause,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.fullscreen,
                                        color: Colors.white70, size: 20),
                                    onPressed: () {},
                                  ),
                                ],
                              ),
                              Text('1:45:20', style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        /// Liste de lecture vidéo
        Expanded(
          flex: 2,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              /// Infos vidéo en cours
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Film_4K_HDR.mkv',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'H.265 • 3840×2160 • HDR10+ • Dolby Vision • 23.976fps',
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          Chip(
                            avatar: const Icon(Icons.subtitles, size: 14),
                            label: const Text('FR'),
                            visualDensity: VisualDensity.compact,
                          ),
                          Chip(
                            avatar: const Icon(Icons.record_voice_over, size: 14),
                            label: const Text('5.1'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              /// Fichiers vidéo du dossier
              ...List.generate(5, (i) => ListTile(
                leading: Container(
                  width: 64,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.movie, size: 20),
                ),
                title: Text('Vidéo ${i + 1}.mkv'),
                subtitle: Text('${[4, 8, 2, 1, 4][i]}K • ${[2.3, 5.1, 1.8, 0.9, 3.2][i]} GB'),
                trailing: IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {},
                ),
              )),
            ],
          ),
        ),
      ],
    );
  }

  /// Options sous-titres IA
  void _showSubtitleOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView(
        padding: const EdgeInsets.all(24),
        shrinkWrap: true,
        children: [
          Text('Sous-titres IA', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Génération auto si absent • Traduction 50 langues',
              style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Génération auto sous-titres'),
            subtitle: const Text('IA Whisper locale si pas de SRT'),
            value: true,
            onChanged: (_) {},
          ),
          ListTile(
            title: const Text('Langue source'),
            subtitle: const Text('Auto-détection'),
            trailing: const Icon(Icons.chevron_right),
          ),
          ListTile(
            title: const Text('Langue traduction'),
            subtitle: const Text('Français'),
            trailing: const Icon(Icons.chevron_right),
          ),
          const Divider(),
          Text('Sous-titres disponibles', style: Theme.of(context).textTheme.titleSmall),
          ...['Français', 'English', 'Español', '日本語'].map(
            (l) => ListTile(
              title: Text(l),
              trailing: l == 'Français'
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}

/// ─── MODE KIDS ───
class _KidsModeView extends StatelessWidget {
  const _KidsModeView();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      color: cs.primaryContainer.withOpacity(0.3),
      child: Column(
        children: [
          /// Bannière mode kids
          Container(
            padding: const EdgeInsets.all(16),
            color: cs.primary,
            child: Row(
              children: [
                const Icon(Icons.child_care, color: Colors.white),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Mode Kids activé',
                    style: TextStyle(color: Colors.white, fontSize: 18)),
                ),
                IconButton(
                  icon: const Icon(Icons.lock, color: Colors.white),
                  onPressed: () {
                    /// Nécessite PIN parent pour sortir
                  },
                ),
              ],
            ),
          ),

          /// Contenu éducatif
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1,
              ),
              itemCount: 9,
              itemBuilder: (context, i) => Card(
                child: InkWell(
                  onTap: () {},
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        [Icons.school, Icons.palette, Icons.music_note,
                         Icons.pets, Icons.nature, Icons.science,
                         Icons.flight, Icons.sports_soccer, Icons.auto_stories][i],
                        size: 40,
                        color: cs.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ['ABC', 'Dessin', 'Musique', 'Animaux',
                         'Nature', 'Science', 'Avions', 'Sport', 'Histoires'][i],
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ─── CARTE OUTIL VIDÉO ───
class _VideoToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _VideoToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

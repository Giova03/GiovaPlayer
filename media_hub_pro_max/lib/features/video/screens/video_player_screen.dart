import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';

/// ─── ÉCRAN VIDÉO GIOVAPLAYER ───
/// Interface complète du lecteur vidéo
/// En production : intégrer media_kit pour lecture réelle

class VideoPlayerScreen extends ConsumerStatefulWidget {
  const VideoPlayerScreen({super.key});
  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  bool _isPlaying = false;
  double _progress = 0.0;
  double _playbackSpeed = 1.0;
  bool _isFullscreen = false;

  final _videos = [
    ('Film_4K_HDR.mkv', 'H.265 • 3840x2160 • HDR10+ • 23.976fps', 2.5, '4K'),
    ('Serie_S01E01.mp4', 'H.264 • 1920x1080 • AAC 5.1', 0.8, '1080p'),
    ('Clip_Musical.mkv', 'H.265 • 3840x2160 • FLAC', 1.2, '4K'),
    ('Docu_Nature.mp4', 'H.264 • 1920x1080 • Dolby Vision', 0.5, '1080p'),
    ('Concert_Live.mkv', 'H.265 • 3840x2160 • ATMOS', 3.2, '4K'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isKids = ref.watch(kidsModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vidéo Pro'),
        actions: [
          IconButton(icon: const Icon(Icons.threed_rotation), onPressed: _showVr, tooltip: 'VR 360'),
          IconButton(icon: Icon(isKids ? Icons.child_care : Icons.child_care_outlined),
            onPressed: () => ref.read(kidsModeProvider.notifier).state = !isKids, tooltip: 'Mode Kids'),
          IconButton(icon: const Icon(Icons.movie_edit), onPressed: _showVideoTools, tooltip: 'Outils'),
        ],
      ),
      body: isKids ? _buildKidsMode(cs) : _buildPlayer(cs),
    );
  }

  Widget _buildPlayer(ColorScheme cs) {
    return Column(children: [
      /// Zone vidéo avec contrôles
      Expanded(flex: 3, child: Container(color: Colors.black, child: Stack(alignment: Alignment.center, children: [
        /// Play/Pause central
        GestureDetector(
          onTap: () => setState(() => _isPlaying = !_isPlaying),
          child: Icon(_isPlaying ? Icons.pause_circle : Icons.play_circle,
            size: 72, color: Colors.white70),
        ),

        /// Badge résolution
        Positioned(top: 12, right: 12, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
          child: const Text('HDR10+ • 4K', style: TextStyle(color: Colors.white, fontSize: 11)),
        )),

        /// Contrôles overlay
        Positioned(bottom: 0, left: 0, right: 0, child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black87])),
          child: Column(children: [
            SliderTheme(data: const SliderThemeData(thumbColor: Colors.red, activeTrackColor: Colors.red),
              child: Slider(value: _progress, onChanged: (v) => setState(() => _progress = v))),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('12:34', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Row(children: [
                IconButton(icon: const Icon(Icons.subtitles, color: Colors.white70, size: 20), onPressed: _showSubtitles),
                IconButton(icon: const Icon(Icons.speed, color: Colors.white70, size: 20), onPressed: _showSpeed),
                IconButton(icon: const Icon(Icons.fullscreen, color: Colors.white70, size: 20), onPressed: () {}),
                IconButton(icon: const Icon(Icons.lock_open, color: Colors.white70, size: 20), onPressed: () {}),
              ]),
              Text('1:45:20', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ]),
        )),
      ]))),

      /// Liste vidéos
      Expanded(flex: 2, child: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_videos[0].$1, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(_videos[0].$2, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 8),
          Row(children: [
            Chip(avatar: const Icon(Icons.subtitles, size: 14), label: const Text('FR'), visualDensity: VisualDensity.compact),
            const SizedBox(width: 8),
            Chip(avatar: const Icon(Icons.record_voice_over, size: 14), label: const Text('5.1'), visualDensity: VisualDensity.compact),
            const SizedBox(width: 8),
            Chip(avatar: const Icon(Icons.high_quality, size: 14), label: const Text('HDR10+'), visualDensity: VisualDensity.compact),
          ]),
        ]))),
        const SizedBox(height: 8),
        ..._videos.skip(1).map((v) => ListTile(
          leading: Container(width: 64, height: 40,
            decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.movie, size: 20)),
          title: Text(v.$1),
          subtitle: Text('${v.$4} • ${v.$3} GB'),
        )),
      ])),
    ]);
  }

  Widget _buildKidsMode(ColorScheme cs) {
    return Column(children: [
      Container(padding: const EdgeInsets.all(16), color: cs.primary,
        child: Row(children: [
          const Icon(Icons.child_care, color: Colors.white),
          const SizedBox(width: 12),
          const Expanded(child: Text('Mode Kids activé', style: TextStyle(color: Colors.white, fontSize: 18))),
          IconButton(icon: const Icon(Icons.lock, color: Colors.white), onPressed: () {}),
        ])),
      Expanded(child: GridView.builder(padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1),
        itemCount: 9,
        itemBuilder: (_, i) => Card(child: InkWell(onTap: () {}, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon([Icons.school, Icons.palette, Icons.music_note, Icons.pets, Icons.nature, Icons.science, Icons.flight, Icons.sports_soccer, Icons.auto_stories][i], size: 40, color: cs.primary),
          const SizedBox(height: 8),
          Text(['ABC','Dessin','Musique','Animaux','Nature','Science','Avions','Sport','Histoires'][i], style: Theme.of(context).textTheme.bodySmall),
        ])))),
      ),
    ]);
  }

  void _showSubtitles() {
    showModalBottomSheet(context: context, builder: (_) => ListView(padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
      Text('Sous-titres IA', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text('Génération auto si absent • Traduction 50 langues',
        style: TextStyle(color: Theme.of(context).colorScheme.primary)),
      const SizedBox(height: 16),
      SwitchListTile(title: const Text('Génération auto'), subtitle: const Text('IA Whisper locale'), value: true, onChanged: (_) {}),
      SwitchListTile(title: const Text('Traduction auto'), subtitle: const Text('Vers FR par défaut'), value: false, onChanged: (_) {}),
      const Divider(),
      Text('Sous-titres disponibles', style: Theme.of(context).textTheme.titleSmall),
      ...['Français', 'English', 'Español', '日本語', 'العربية', '中文']
        .map((l) => ListTile(title: Text(l), trailing: l == 'Français' ? const Icon(Icons.check) : null, onTap: () {})),
    ]));
  }

  void _showSpeed() {
    showModalBottomSheet(context: context, builder: (_) => ListView(padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
      Text('Vitesse de lecture', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0]
        .map((s) => ChoiceChip(label: Text('${s}x'), selected: _playbackSpeed == s, onSelectionChanged: (_) {
          setState(() => _playbackSpeed = s);
          Navigator.pop(context);
        })).toList()),
    ]));
  }

  void _showVr() {
    showModalBottomSheet(context: context, builder: (_) => ListView(padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
      Text('Mode VR 360', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      SwitchListTile(title: const Text('Vue 360'), subtitle: const Text('Rotation libre gyroscope'), value: false, onChanged: (_) {}),
      SwitchListTile(title: const Text('Split écran VR'), subtitle: const Text('Pour casques Cardboard'), value: false, onChanged: (_) {}),
      SwitchListTile(title: const Text('Gyroscope'), subtitle: const Text('Rotation avec le téléphone'), value: false, onChanged: (_) {}),
    ]));
  }

  void _showVideoTools() {
    showModalBottomSheet(context: context, isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(initialChildSize: 0.5, expand: false,
        builder: (ctx, ctrl) => ListView(controller: ctrl, padding: const EdgeInsets.all(24), children: [
          Text('Outils Vidéo', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ...[(Icons.content_cut, 'Découpe sans perte', 'Coupez sans ré-encoder'),
            (Icons.merge, 'Fusion vidéos', 'Assemblez plusieurs clips'),
            (Icons.branding_watermark, 'Filigrane', 'Logo ou texte personnalisé'),
            (Icons.subtitles, 'Extracteur sous-titres', 'Extraire SRT/ASS'),
            (Icons.audiotrack, 'Extracteur audio', 'Vidéo vers MP3/FLAC'),
            (Icons.compress, 'Compresseur H.265', 'Réduire taille'),
            (Icons.gif, 'GIF animé', 'Extraire segment en GIF'),
            (Icons.screenshot, 'Capture écran', 'Screenshot vidéo en image'),
          ].map((t) => Card(margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(leading: Icon(t.$1, color: Theme.of(context).colorScheme.primary),
              title: Text(t.$2), subtitle: Text(t.$3), trailing: const Icon(Icons.chevron_right), onTap: () {}))),
        ])));
  }
}

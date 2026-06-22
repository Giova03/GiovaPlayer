import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ─── ÉCRAN LECTEUR AUDIO HI-RES ───
/// Features: FLAC/WAV/DSF, EQ 32 bandes, Paroles LRC, Crossfade,
/// BPM détection, Tags, Chromecast/AirPlay
class AudioPlayerScreen extends ConsumerStatefulWidget {
  const AudioPlayerScreen({super.key});

  @override
  ConsumerState<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends ConsumerState<AudioPlayerScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isPlaying = false;
  double _progress = 0.35;
  double _volume = 0.8;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Hi-Res'),
        actions: [
          /// Bouton Chromecast / AirPlay
          IconButton(
            icon: const Icon(Icons.cast),
            onPressed: _onCastPressed,
            tooltip: 'Cast',
          ),
          /// Égaliseur
          IconButton(
            icon: const Icon(Icons.graphic_eq),
            onPressed: _showEqualizer,
            tooltip: 'Égaliseur',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Lecteur'),
            Tab(text: 'Paroles'),
            Tab(text: 'Bibliothèque'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PlayerTab(
            isPlaying: _isPlaying,
            progress: _progress,
            volume: _volume,
            onPlayPause: _togglePlay,
            onProgressChanged: (v) => setState(() => _progress = v),
            onVolumeChanged: (v) => setState(() => _volume = v),
          ),
          const _LyricsTab(),
          const _LibraryTab(),
        ],
      ),
    );
  }

  /// Bascule lecture/pause
  void _togglePlay() => setState(() => _isPlaying = !_isPlaying);

  /// Ouvre le panneau Cast (Chromecast/AirPlay)
  void _onCastPressed() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _CastBottomSheet(),
    );
  }

  /// Affiche l'égaliseur 32 bandes + presets IA
  void _showEqualizer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _EqualizerSheet(),
    );
  }
}

/// ─── ONGLET LECTEUR ───
class _PlayerTab extends StatelessWidget {
  final bool isPlaying;
  final double progress;
  final double volume;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onProgressChanged;
  final ValueChanged<double> onVolumeChanged;

  const _PlayerTab({
    required this.isPlaying,
    required this.progress,
    required this.volume,
    required this.onPlayPause,
    required this.onProgressChanged,
    required this.onVolumeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          /// Pochette d'album avec animation
          Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: cs.surfaceContainerHighest,
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.album, size: 80),
            ),
          ),
          const SizedBox(height: 24),

          /// Titre + Artiste
          Text(
            'Morceau en cours',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Artiste • Album • FLAC 24bit/96kHz',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),

          /// Barre de progression
          Slider(
            value: progress,
            onChanged: onProgressChanged,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('1:24', style: TextStyle(color: cs.onSurfaceVariant)),
                Text('3:58', style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          /// Contrôles principaux
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shuffle),
                onPressed: () {},
                iconSize: 24,
              ),
              IconButton(
                icon: const Icon(Icons.skip_previous, size: 36),
                onPressed: () {},
              ),
              const SizedBox(width: 8),
              FloatingActionButton.large(
                onPressed: onPlayPause,
                child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, size: 40),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.skip_next, size: 36),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.repeat),
                onPressed: () {},
                iconSize: 24,
              ),
            ],
          ),
          const SizedBox(height: 16),

          /// Volume + BPM + ReplayGain
          Row(
            children: [
              const Icon(Icons.volume_down),
              Expanded(
                child: Slider(
                  value: volume,
                  onChanged: onVolumeChanged,
                ),
              ),
              const Icon(Icons.volume_up),
              const SizedBox(width: 16),
              Chip(
                avatar: const Icon(Icons.speed, size: 16),
                label: const Text('128 BPM'),
              ),
              const SizedBox(width: 8),
              Chip(
                avatar: const Icon(Icons.equalizer, size: 16),
                label: const Text('RG -3.2dB'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ─── ONGLET PAROLES LRC + KARAOKÉ ───
class _LyricsTab extends StatelessWidget {
  const _LyricsTab();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          /// Mode karaoké toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilterChip(
                label: const Text('Karaoké'),
                selected: false,
                onSelected: (_) {},
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Traduction'),
                selected: false,
                onSelected: (_) {},
              ),
            ],
          ),
          const SizedBox(height: 24),

          /// Paroles défilantes
          Expanded(
            child: ListView(
              children: [
                _LyricLine('Paroles synchronisées LRC', isActive: true),
                _LyricLine('Surlignées en temps réel'),
                _LyricLine('Traduction disponible en bas'),
                _LyricLine('Glissez pour changer de langue'),
                _LyricLine('Mode karaoké avec suivi vocal'),
                _LyricLine('Appuyez sur une ligne pour sauter'),
                _LyricLine('Export SRT / LRC possible'),
                _LyricLine('Recherche paroles en ligne si absent'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LyricLine extends StatelessWidget {
  final String text;
  final bool isActive;

  const _LyricLine(this.text, {this.isActive = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isActive ? 20 : 16,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
          color: isActive ? cs.primary : cs.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// ─── ONGLET BIBLIOTHÈQUE ───
class _LibraryTab extends StatelessWidget {
  const _LibraryTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        /// Barre de recherche
        TextField(
          decoration: InputDecoration(
            hintText: 'Rechercher morceaux, artistes, albums...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
        ),
        const SizedBox(height: 16),

        /// Filtres par genre (détecté par IA)
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              'Tout', 'Rock', 'Jazz', 'Électro', 'Classique', 'Hip-Hop', 'Pop'
            ].map((g) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(label: Text(g), onSelected: (_) {}),
            )).toList(),
          ),
        ),
        const SizedBox(height: 16),

        /// Liste de morceaux
        ...List.generate(10, (i) => _TrackTile(index: i)),
      ],
    );
  }
}

class _TrackTile extends StatelessWidget {
  final int index;
  const _TrackTile({required this.index});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.music_note),
      ),
      title: Text('Morceau ${index + 1}'),
      subtitle: Text('Artiste ${index + 1} • FLAC ${[96, 192, 44.1][index % 3]}kHz'),
      trailing: PopupMenuButton(
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'tags', child: Text('Éditer tags')),
          const PopupMenuItem(value: 'lyrics', child: Text('Chercher paroles')),
          const PopupMenuItem(value: 'bpm', child: Text('Détection BPM')),
          const PopupMenuItem(value: 'crossfade', child: Text('Crossfade vers...')),
        ],
      ),
    );
  }
}

/// ─── PANNEAU CAST CHROMECAST/AIRPLAY ───
class _CastBottomSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      shrinkWrap: true,
      children: [
        Text('Diffuser vers...',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.speaker),
          title: const Text('Enceinte Salon'),
          subtitle: const Text('Chromecast Audio • FLAC'),
          trailing: const Icon(Icons.radio_button_checked),
          onTap: () => Navigator.pop(context),
        ),
        ListTile(
          leading: const Icon(Icons.airplay),
          title: const Text('Apple TV Salon'),
          subtitle: const Text('AirPlay • AAC 256'),
          trailing: const Icon(Icons.radio_button_unchecked),
          onTap: () => Navigator.pop(context),
        ),
        ListTile(
          leading: const Icon(Icons.bluetooth),
          title: const Text('Sony WH-1000XM5'),
          subtitle: const Text('Bluetooth • LDAC'),
          trailing: const Icon(Icons.radio_button_unchecked),
          onTap: () => Navigator.pop(context),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.bluetooth_connected),
          title: const Text('Double écoute BT'),
          subtitle: const Text('Synchroniser 2 appareils Bluetooth'),
          trailing: Switch(value: false, onChanged: (_) {}),
        ),
      ],
    );
  }
}

/// ─── ÉGALISEUR 32 BANDES + PRESETS IA ───
class _EqualizerSheet extends StatelessWidget {
  const _EqualizerSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Text('Égaliseur 32 bandes',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Presets IA détectés : Rock', style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
            )),
            const SizedBox(height: 16),

            /// Presets horizontaux
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  'Auto IA', 'Flat', 'Rock', 'Jazz', 'Classique',
                  'Bass Boost', 'Vocal', 'Électro', 'Acoustique',
                ].map((p) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(label: Text(p), onSelected: (_) {}),
                )).toList(),
              ),
            ),
            const SizedBox(height: 24),

            /// Visualisation 32 bandes
            SizedBox(
              height: 200,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(32, (i) {
                  /// Valeurs simulées pour la démo
                  final h = [0.6, 0.7, 0.75, 0.8, 0.85, 0.9, 0.88,
                    0.82, 0.78, 0.72, 0.68, 0.65, 0.6, 0.58, 0.55,
                    0.53, 0.5, 0.52, 0.55, 0.58, 0.6, 0.62, 0.58,
                    0.55, 0.5, 0.48, 0.45, 0.42, 0.4, 0.38, 0.35, 0.32][i];
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: h * 160,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),

            /// Fréquences label
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('20Hz', style: TextStyle(fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
                Text('1kHz', style: TextStyle(fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
                Text('20kHz', style: TextStyle(fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),

            const SizedBox(height: 24),

            /// Contrôles ReplayGain + Crossfade + Gapless
            SwitchListTile(
              title: const Text('ReplayGain Auto'),
              subtitle: const Text('Normalise le volume entre morceaux'),
              value: true,
              onChanged: (_) {},
            ),
            SwitchListTile(
              title: const Text('Gapless Playback'),
              subtitle: const Text('Sans silence entre morceaux'),
              value: true,
              onChanged: (_) {},
            ),
            ListTile(
              title: const Text('Crossfade'),
              subtitle: const Text('3 secondes'),
              trailing: SizedBox(
                width: 120,
                child: Slider(value: 3, min: 0, max: 12, onChanged: (_) {}),
              ),
            ),
          ],
        );
      },
    );
  }
}

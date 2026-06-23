import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/file_scanner.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  const VideoPlayerScreen({super.key});
  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  int _selectedIndex = -1;
  double _playbackSpeed = 1.0;
  String _searchQuery = '';

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initPlayer(String path) async {
    _controller?.dispose();
    _controller = VideoPlayerController.file(File(path));
    try {
      await _controller!.initialize();
      setState(() => _isInitialized = true);
      _controller!.play();
      _controller!.setLooping(true);
    } catch (e) {
      setState(() => _isInitialized = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lecture: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final videoFilesAsync = ref.watch(videoFilesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vidéo Pro'),
        actions: [
          IconButton(icon: const Icon(Icons.movie_edit), onPressed: _tools),
        ],
      ),
      body: videoFilesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.error_outline, size: 64, color: cs.error),
          const SizedBox(height: 16),
          Text('Erreur: $e', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: () => ref.invalidate(videoFilesProvider),
            icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
        ])),
        data: (files) => Column(children: [
          // Lecteur vidéo
          Container(
            height: 220,
            color: Colors.black,
            child: _selectedIndex >= 0 && _isInitialized && _controller != null
              ? Stack(alignment: Alignment.center, children: [
                  AspectRatio(aspectRatio: _controller!.value.aspectRatio,
                    child: VideoPlayer(_controller!)),
                  // Contrôles overlay
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
                      });
                    },
                    child: Center(child: Icon(
                      _controller!.value.isPlaying ? Icons.pause_circle : Icons.play_circle,
                      size: 56, color: Colors.white70)),
                  ),
                  // Barre de progression
                  Positioned(bottom: 0, left: 0, right: 0,
                    child: Container(padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87])),
                      child: Column(children: [
                        VideoProgressIndicator(_controller!, allowScrubbing: true,
                          colors: const VideoProgressColors(playedColor: Colors.red, bufferedColor: Colors.redAccent)),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(_fmt(_controller!.value.position), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          Row(children: [
                            IconButton(icon: const Icon(Icons.speed, color: Colors.white70, size: 18), onPressed: _speedMenu),
                            IconButton(icon: const Icon(Icons.fullscreen, color: Colors.white70, size: 18), onPressed: (){}),
                          ]),
                          Text(_fmt(_controller!.value.duration), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        ]),
                      ]))),
                ])
              : Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.play_circle_outline, size: 56, color: Colors.white54),
                  const SizedBox(height: 8),
                  Text('Sélectionnez une vidéo', style: TextStyle(color: Colors.white54)),
                ])),
          ),
          // Barre de recherche
          Padding(padding: const EdgeInsets.all(8),
            child: TextField(decoration: InputDecoration(
              hintText: 'Rechercher vidéos...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
            ), onChanged: (v) => setState(() => _searchQuery = v))),
          // Liste des vidéos
          Expanded(child: files.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.movie, size: 64, color: cs.onSurfaceVariant.withOpacity(0.5)),
                const SizedBox(height: 16),
                const Text('Aucune vidéo trouvée'),
                const SizedBox(height: 8),
                Text('Vérifiez les permissions', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                const SizedBox(height: 16),
                FilledButton.icon(onPressed: () => ref.invalidate(videoFilesProvider),
                  icon: const Icon(Icons.refresh), label: const Text('Rescanner')),
              ]))
            : ListView.builder(itemCount: files.length, itemBuilder: (_, i) {
                final f = files[i];
                if (_searchQuery.isNotEmpty && !f.displayName.toLowerCase().contains(_searchQuery.toLowerCase())) {
                  return const SizedBox.shrink();
                }
                final isSelected = i == _selectedIndex;
                return ListTile(
                  selected: isSelected,
                  selectedTileColor: cs.primaryContainer.withOpacity(0.3),
                  leading: Container(width: 56, height: 36,
                    decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.movie, size: 18)),
                  title: Text(f.displayName, style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${f.extension.toUpperCase().replaceAll('.', '')} • ${f.sizeFormatted}',
                    style: const TextStyle(fontSize: 11)),
                  trailing: isSelected ? Icon(Icons.play_circle_filled, color: cs.primary) : null,
                  onTap: () {
                    setState(() { _selectedIndex = i; _isInitialized = false; });
                    _initPlayer(f.path);
                  },
                );
              }),
          ),
        ]),
      ),
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _speedMenu() => showModalBottomSheet(context: context, builder: (_) => Padding(
    padding: const EdgeInsets.all(24), child: Wrap(spacing: 8, runSpacing: 8, children:
      [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((s) => ChoiceChip(
        label: Text('${s}x'), selected: _playbackSpeed == s,
        onSelected: (_) {
          _playbackSpeed = s;
          _controller?.setPlaybackSpeed(s);
          Navigator.pop(context);
        })).toList())));

  void _tools() => showModalBottomSheet(context: context, builder: (_) => ListView(
    padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
    Text('Outils Vidéo', style: Theme.of(context).textTheme.titleLarge),
    ...[(Icons.content_cut, 'Découpe', 'Coupez sans ré-encoder'),
      (Icons.merge, 'Fusion', 'Assemblez clips'),
      (Icons.branding_watermark, 'Filigrane', 'Logo ou texte'),
      (Icons.subtitles, 'Sous-titres', 'Extraire SRT'),
      (Icons.audiotrack, 'Audio', 'Extraire MP3/FLAC'),
      (Icons.compress, 'Compresser', 'H.265'),
      (Icons.gif, 'GIF', 'Segment en GIF'),
      (Icons.screenshot, 'Capture', 'Screenshot vidéo')].map((t) =>
      ListTile(leading: Icon(t.$1, color: Theme.of(context).colorScheme.primary),
        title: Text(t.$2), subtitle: Text(t.$3))),
  ]));
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/file_scanner.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  const VideoPlayerScreen({super.key});
  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  bool _isInit = false;
  int _selIdx = -1;
  double _speed = 1.0;
  bool _showCtrl = true;
  bool _fullscreen = false;
  String _search = '';
  double _volume = 1.0;
  bool _isBuffering = false;

  @override
  void initState() {
    super.initState();
    _player = Player(configuration: const PlayerConfiguration(title: 'GiovaPlayer'));
    _controller = VideoController(_player);
    _player.stream.buffering.listen((b) => setState(() => _isBuffering = b));
  }

  @override
  void dispose() {
    _player.dispose();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> _init(String path) async {
    try {
      await _player.open(Media(path));
      await WakelockPlus.enable();
      await _player.setPlaybackMode(PlaybackMode.passthrough);
      setState(() => _isInit = true);
      _player.play();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    }
  }

  void _toggleFS() {
    setState(() => _fullscreen = !_fullscreen);
    if (_fullscreen) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_fullscreen && _isInit) return _fullPlayer();
    final cs = Theme.of(context).colorScheme;
    return Scaffold(appBar: AppBar(title: const Text('Vidéo Pro'), actions: [
      IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(videoFilesProvider)),
    ]), body: ref.watch(videoFilesProvider).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: FilledButton(onPressed: () => ref.invalidate(videoFilesProvider), child: Text('Erreur: $e'))),
      data: (files) => Column(children: [
        _inlinePlayer(cs),
        Padding(padding: const EdgeInsets.fromLTRB(8,4,8,0), child: TextField(decoration: InputDecoration(
          hintText: 'Rechercher...', prefixIcon: const Icon(Icons.search, size: 20), isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
        ), onChanged: (v) => setState(() => _search = v))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), child: Row(children: [
          Text('${files.length} vidéos', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          const Spacer(),
          Text('Formats: MKV AVI MOV MP4 WEBM FLV WMV', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
        ])),
        Expanded(child: _videoList(files, cs)),
      ]),
    ));
  }

  Widget _inlinePlayer(ColorScheme cs) => GestureDetector(onTap: () => setState(() => _showCtrl = !_showCtrl),
    child: Container(height: 220, color: Colors.black,
      child: _selIdx >= 0 && _isInit
        ? Stack(alignment: Alignment.center, children: [
            Video(controller: _controller, width: double.infinity, height: 220),
            if (_showCtrl) _controls(false),
          ])
        : Center(child: Icon(Icons.play_circle_outline, size: 56, color: Colors.white54))));

  Widget _fullPlayer() => Scaffold(backgroundColor: Colors.black, body: GestureDetector(
    onTap: () => setState(() => _showCtrl = !_showCtrl),
    child: Stack(fit: StackFit.expand, children: [
      Center(child: Video(controller: _controller)),
      if (_showCtrl) _controls(true),
    ]),
  ));

  Widget _controls(bool fs) {
    final state = _player.state;
    final pos = state.position;
    final dur = state.duration;
    final playing = state.playing;

    return Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87])),
      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
        if (fs) Padding(padding: const EdgeInsets.only(top: 20, left: 16), child: Row(children: [
          IconButton(icon: const Icon(Icons.fullscreen_exit, color: Colors.white), onPressed: _toggleFS),
        ])),
        const Spacer(),
        if (_isBuffering) const Center(child: CircularProgressIndicator(color: Colors.white)),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(icon: const Icon(Icons.replay_10, color: Colors.white, size: 28), onPressed: () => _player.seek(pos - const Duration(seconds: 10))),
          const SizedBox(width: 16),
          GestureDetector(onTap: () => playing ? _player.pause() : _player.play(),
            child: Container(decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white24), padding: const EdgeInsets.all(16),
              child: Icon(playing ? Icons.pause : Icons.play_arrow, size: 48, color: Colors.white))),
          const SizedBox(width: 16),
          IconButton(icon: const Icon(Icons.forward_10, color: Colors.white, size: 28), onPressed: () => _player.seek(pos + const Duration(seconds: 10))),
        ]),
        const Spacer(),
        // Progress bar
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: StreamBuilder<Duration>(stream: _player.stream.position, builder: (_, snap) {
            final p = snap.data ?? pos;
            return Column(children: [
              Slider(value: dur.inMilliseconds > 0 ? p.inMilliseconds.toDouble().clamp(0, dur.inMilliseconds.toDouble()) : 0,
                min: 0, max: dur.inMilliseconds.toDouble() > 0 ? dur.inMilliseconds.toDouble() : 1,
                onChanged: (v) => _player.seek(Duration(milliseconds: v.round()))),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(_fmt(p), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text(_fmt(dur), style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ]);
          })),
        Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, fs ? 24 : 8), child: Row(children: [
          Text(_selName, style: const TextStyle(color: Colors.white70, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          const Spacer(),
          // Volume
          IconButton(icon: Icon(_volume > 0 ? Icons.volume_up : Icons.volume_off, color: Colors.white70, size: 18),
            onPressed: () { setState(() { _volume = _volume > 0 ? 0 : 1.0; }); _player.setVolume(_volume); }),
          // Speed
          IconButton(icon: const Icon(Icons.speed, color: Colors.white70, size: 18), onPressed: _speedMenu),
          // Fullscreen
          IconButton(icon: Icon(fs ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white70, size: 18), onPressed: _toggleFS),
        ])),
      ]),
    );
  }

  Widget _videoList(List<MediaFile> files, ColorScheme cs) {
    final filtered = _search.isEmpty ? files : files.where((f) => f.displayName.toLowerCase().contains(_search.toLowerCase())).toList();
    if (files.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.movie, size: 64, color: cs.onSurfaceVariant.withOpacity(0.5)), const SizedBox(height: 16), const Text('Aucune vidéo'),
      const SizedBox(height: 16), FilledButton.icon(onPressed: () => ref.invalidate(videoFilesProvider), icon: const Icon(Icons.refresh), label: const Text('Rescanner')),
    ]));
    return ListView.builder(itemCount: filtered.length, itemBuilder: (_, i) {
      final f = filtered[i]; final sel = i == _selIdx;
      return ListTile(selected: sel, leading: Container(width: 64, height: 40,
        decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
        child: Stack(alignment: Alignment.center, children: [const Icon(Icons.movie, size: 18), if (sel) Icon(Icons.play_circle, color: cs.primary)])),
        title: Text(f.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
        subtitle: Text('${f.extension.toUpperCase().replaceAll('.', '')} • ${f.sizeFormatted}', style: const TextStyle(fontSize: 11)),
        onTap: () { setState(() { _selIdx = i; _isInit = false; }); _init(f.path); },
        trailing: IconButton(icon: const Icon(Icons.fullscreen), onPressed: () {
          setState(() { _selIdx = i; _isInit = false; }); _init(f.path).then((_) { if (_isInit) _toggleFS(); });
        }),
      );
    });
  }

  String get _selName { final f = ref.read(videoFilesProvider).valueOrNull ?? []; return _selIdx >= 0 && _selIdx < f.length ? f[_selIdx].displayName : ''; }

  void _speedMenu() => showModalBottomSheet(context: context, builder: (_) => Padding(padding: const EdgeInsets.all(24),
    child: Wrap(spacing: 8, runSpacing: 8, children: [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0].map((s) =>
      ChoiceChip(label: Text('${s}x'), selected: _speed == s, onSelected: (_) { _speed = s; _player.setRate(s); Navigator.pop(context); })).toList())));

  String _fmt(Duration d) { final h = d.inHours; final m = d.inMinutes.remainder(60); final s = d.inSeconds.remainder(60); return h > 0 ? '$h:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}' : '$m:${s.toString().padLeft(2,'0')}'; }
}

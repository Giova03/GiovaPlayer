import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/database/app_database.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  const VideoPlayerScreen({super.key});
  @override
  ConsumerState<VideoPlayerScreen> createState() => _S();
}
class _S extends ConsumerState<VideoPlayerScreen> {
  bool _playing = false; double _prog = 0;
  final _vids = AppDatabase.instance.getMediaByType('video');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final kids = ref.watch(kidsModeProvider);
    return Scaffold(appBar: AppBar(title: const Text('Video Pro'), actions: [
      IconButton(icon: const Icon(Icons.threed_rotation), onPressed: _vr),
      IconButton(icon: Icon(kids ? Icons.child_care : Icons.child_care_outlined),
        onPressed: () => ref.read(kidsModeProvider.notifier).state = !kids),
      IconButton(icon: const Icon(Icons.movie_edit), onPressed: _tools),
    ]), body: kids ? _kids(cs) : _player(cs));
  }

  Widget _player(ColorScheme cs) => Column(children: [
    Expanded(flex: 3, child: Container(color: Colors.black, child: Stack(alignment: Alignment.center, children: [
      GestureDetector(onTap: () => setState(() => _playing = !_playing),
        child: Icon(_playing ? Icons.pause_circle : Icons.play_circle, size: 72, color: Colors.white70)),
      Positioned(top: 12, right: 12, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
        child: const Text('HDR10+ 4K', style: TextStyle(color: Colors.white, fontSize: 11)))),
      Positioned(bottom: 0, left: 0, right: 0, child: Container(padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87])),
        child: Column(children: [
          SliderTheme(data: const SliderThemeData(thumbColor: Colors.red, activeTrackColor: Colors.red),
            child: Slider(value: _prog, onChanged: (v) => setState(() => _prog = v))),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('12:34', style: TextStyle(color: Colors.white70, fontSize: 12)),
            Row(children: [
              IconButton(icon: const Icon(Icons.subtitles, color: Colors.white70, size: 20), onPressed: _subs),
              IconButton(icon: const Icon(Icons.speed, color: Colors.white70, size: 20), onPressed: _speed),
              IconButton(icon: const Icon(Icons.fullscreen, color: Colors.white70, size: 20), onPressed: (){}),
            ]),
            Text('1:45:20', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ]))),
    ]))),
    Expanded(flex: 2, child: ListView(padding: const EdgeInsets.all(16), children: [
      ..._vids.map((v) => ListTile(
        leading: Container(width: 56, height: 36, decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
          child: const Icon(Icons.movie, size: 18)),
        title: Text(v['title'] ?? '', style: const TextStyle(fontSize: 13)),
        subtitle: Text(v['format'] ?? '', style: const TextStyle(fontSize: 11)),
        onTap: (){},
      )),
    ])),
  ]);

  Widget _kids(ColorScheme cs) => Column(children: [
    Container(padding: const EdgeInsets.all(16), color: cs.primary,
      child: const Row(children: [Icon(Icons.child_care, color: Colors.white), SizedBox(width: 12),
        Expanded(child: Text('Mode Kids', style: TextStyle(color: Colors.white, fontSize: 18)))])),
    Expanded(child: GridView.count(crossAxisCount: 3, padding: const EdgeInsets.all(16), children:
      [Icons.school, Icons.palette, Icons.music_note, Icons.pets, Icons.nature, Icons.science, Icons.flight, Icons.sports_soccer, Icons.auto_stories].map((i) =>
        Card(child: InkWell(onTap: (){}, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(i, size: 36, color: cs.primary)])))).toList())),
  ]);

  void _subs() => showModalBottomSheet(context: context, builder: (_) => ListView(padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
    Text('Sous-titres IA', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 8),
    const Text('Generation auto si absent • Traduction 50 langues'),
    const SizedBox(height: 16),
    SwitchListTile(title: const Text('Generation auto'), value: true, onChanged: (_){}),
    SwitchListTile(title: const Text('Traduction auto'), value: false, onChanged: (_){}),
    ...['Francais','English','Espanol'].map((l) => ListTile(title: Text(l), trailing: l == 'Francais' ? const Icon(Icons.check) : null)),
  ]));
  void _speed() => showModalBottomSheet(context: context, builder: (_) => Wrap(spacing: 8, runSpacing: 8, children:
    [0.25,0.5,0.75,1.0,1.25,1.5,2.0].map((s) => ChoiceChip(label: Text('${s}x'), selected: s == 1.0, onSelected: (_){})).toList()));
  void _vr() => showModalBottomSheet(context: context, builder: (_) => ListView(padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
    Text('VR 360', style: Theme.of(context).textTheme.titleLarge),
    SwitchListTile(title: const Text('Vue 360'), value: false, onChanged: (_){}),
    SwitchListTile(title: const Text('Split ecran'), value: false, onChanged: (_){}),
  ]));
  void _tools() => showModalBottomSheet(context: context, builder: (_) => ListView(padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
    Text('Outils Video', style: Theme.of(context).textTheme.titleLarge),
    ...[(Icons.content_cut,'Decoupe','Coupez sans re-encoder'),(Icons.merge,'Fusion','Assemblez clips'),
      (Icons.branding_watermark,'Filigrane','Logo ou texte'),(Icons.subtitles,'Sous-titres','Extraire SRT'),
      (Icons.audiotrack,'Audio','Extraire MP3/FLAC'),(Icons.compress,'Compresser','H.265'),
      (Icons.gif,'GIF','Segment en GIF'),(Icons.screenshot,'Capture','Screenshot video')].map((t) =>
      ListTile(leading: Icon(t.$1, color: Theme.of(context).colorScheme.primary), title: Text(t.$2), subtitle: Text(t.$3))),
  ]));
}

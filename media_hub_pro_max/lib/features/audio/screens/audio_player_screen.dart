import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/database/app_database.dart';

class AudioPlayerScreen extends ConsumerStatefulWidget {
  const AudioPlayerScreen({super.key});
  @override
  ConsumerState<AudioPlayerScreen> createState() => _S();
}

class _S extends ConsumerState<AudioPlayerScreen> with TickerProviderStateMixin {
  late TabController _tc;
  final _tracks = AppDatabase.instance.getMediaByType('audio');

  @override void initState() { super.initState(); _tc = TabController(length: 3, vsync: this); }
  @override void dispose() { _tc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final playing = ref.watch(audioPlayingProvider);
    final progress = ref.watch(audioProgressProvider);
    final idx = ref.watch(audioTrackIndexProvider);
    final vol = ref.watch(audioVolumeProvider);
    final spd = ref.watch(audioSpeedProvider);
    final t = _tracks[idx % _tracks.length];

    return Scaffold(appBar: AppBar(title: const Text('Audio Hi-Res'),
      actions: [
        IconButton(icon: const Icon(Icons.graphic_eq), onPressed: _eq, tooltip: 'EQ'),
        IconButton(icon: const Icon(Icons.timer), onPressed: _timer, tooltip: 'Minuterie'),
      ],
      bottom: TabBar(controller: _tc, tabs: const [Tab(text:'Lecteur'), Tab(text:'Paroles'), Tab(text:'Bibliotheque')])),
      body: TabBarView(controller: _tc, children: [
        // LECTEUR
        SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [
          Container(width: 220, height: 220, decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: cs.surfaceContainerHighest,
            boxShadow: [BoxShadow(color: cs.primary.withValues(alpha:0.2), blurRadius: 20, offset: const Offset(0,8))]),
            child: Icon(Icons.album, size: 72, color: cs.primary)),
          const SizedBox(height: 20),
          Text(t['title'] ?? '', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('${t['artist']} • ${t['format']}', style: TextStyle(color: cs.onSurfaceVariant)),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(icon: const Icon(Icons.favorite_border), onPressed: (){}),
            IconButton(icon: const Icon(Icons.share), onPressed: (){}),
            IconButton(icon: const Icon(Icons.playlist_add), onPressed: (){}),
          ]),
          Slider(value: progress, onChanged: (v) => ref.read(audioProgressProvider.notifier).state = v),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text(_fmt((progress * 238000).round()), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                         Text(_fmt(238000), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12))])),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(icon: Icon(Icons.shuffle, color: ref.watch(audioShuffleProvider) ? cs.primary : null),
              onPressed: () => ref.read(audioShuffleProvider.notifier).state = !ref.read(audioShuffleProvider)),
            IconButton(icon: const Icon(Icons.skip_previous, size: 32), onPressed: () {
              ref.read(audioTrackIndexProvider.notifier).state = (idx - 1).clamp(0, _tracks.length - 1);
              ref.read(audioProgressProvider.notifier).state = 0;
            }),
            const SizedBox(width: 8),
            FloatingActionButton.large(onPressed: () => ref.read(audioPlayingProvider.notifier).state = !playing,
              child: Icon(playing ? Icons.pause : Icons.play_arrow, size: 40)),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.skip_next, size: 32), onPressed: () {
              ref.read(audioTrackIndexProvider.notifier).state = (idx + 1) % _tracks.length;
              ref.read(audioProgressProvider.notifier).state = 0;
            }),
            IconButton(icon: Icon([Icons.repeat, Icons.repeat, Icons.repeat_one][ref.watch(audioRepeatProvider)],
              color: ref.watch(audioRepeatProvider) > 0 ? cs.primary : null),
              onPressed: () => ref.read(audioRepeatProvider.notifier).state = (ref.read(audioRepeatProvider) + 1) % 3),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.volume_down, size: 18),
            Expanded(child: Slider(value: vol, onChanged: (v) => ref.read(audioVolumeProvider.notifier).state = v)),
            const Icon(Icons.volume_up, size: 18),
            const SizedBox(width: 12),
            Chip(avatar: const Icon(Icons.speed, size: 14), label: Text('${t['bpm']?.round() ?? 128} BPM')),
          ]),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [0.5,0.75,1.0,1.25,1.5,2.0].map((s) =>
            Padding(padding: const EdgeInsets.only(right: 4), child: ChoiceChip(label: Text('${s}x', style: const TextStyle(fontSize: 10)),
              selected: spd == s, onSelected: (_) => ref.read(audioSpeedProvider.notifier).state = s))).toList()),
        ])),
        // PAROLES
        Padding(padding: const EdgeInsets.all(24), child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            FilterChip(label: const Text('Karaoke'), selected: false, onSelected: (_){}),
            const SizedBox(width: 8),
            FilterChip(label: const Text('Traduction'), selected: false, onSelected: (_){}),
          ]),
          const SizedBox(height: 20),
          Expanded(child: ListView(children: ['Paroles synchronisees LRC', 'Surlignees en temps reel',
            'Traduction disponible en bas', 'Glissez pour changer de langue', 'Mode karaoke avec suivi vocal',
            'Export SRT / LRC possible', 'Recherche paroles en ligne si absent'].map((l) =>
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(l, textAlign: TextAlign.center,
              style: TextStyle(fontSize: l.startsWith('Paroles') ? 20 : 16,
                fontWeight: l.startsWith('Paroles') ? FontWeight.w700 : FontWeight.w400,
                color: l.startsWith('Paroles') ? cs.primary : cs.onSurfaceVariant)))).toList())),
        ])),
        // BIBLIOTHEQUE
        ListView(padding: const EdgeInsets.all(16), children: [
          TextField(decoration: InputDecoration(hintText: 'Rechercher morceaux...',
            prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)))),
          const SizedBox(height: 12),
          SizedBox(height: 36, child: ListView(scrollDirection: Axis.horizontal,
            children: ['Tout','Rock','Jazz','Electro','Classique','Hip-Hop','Afro','Pop','R&B'].map((g) =>
              Padding(padding: const EdgeInsets.only(right: 6), child: FilterChip(label: Text(g, style: const TextStyle(fontSize: 12)), onSelected: (_){}))).toList())),
          const SizedBox(height: 12),
          ..._tracks.map((t) => ListTile(
            leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.music_note, color: cs.primary, size: 22)),
            title: Text(t['title'] ?? '', style: const TextStyle(fontSize: 14)),
            subtitle: Text('${t['artist']} • ${t['format']}', style: const TextStyle(fontSize: 12)),
            trailing: PopupMenuButton(itemBuilder: (_) => [
              const PopupMenuItem(value: 'tags', child: Text('Editer tags')),
              const PopupMenuItem(value: 'ringtone', child: Text('Sonnerie')),
              const PopupMenuItem(value: 'info', child: Text('Infos')),
            ]),
            onTap: () { ref.read(audioTrackIndexProvider.notifier).state = _tracks.indexOf(t); ref.read(audioProgressProvider.notifier).state = 0; },
          )),
        ]),
      ]),
    );
  }

  String _fmt(int ms) { final s = ms ~/ 1000; return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}'; }

  void _eq() => showModalBottomSheet(context: context, builder: (_) => ListView(padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
    Text('Egaliseur 32 bandes', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 12),
    SizedBox(height: 36, child: ListView(scrollDirection: Axis.horizontal,
      children: ['Auto IA','Flat','Rock','Jazz','Classique','Bass+','Vocal+','Treble'].map((p) =>
        Padding(padding: const EdgeInsets.only(right: 6), child: FilterChip(label: Text(p), onSelected: (_){}))).toList())),
    const SizedBox(height: 20),
    SizedBox(height: 150, child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(32, (i) {
        final h = [0.6,0.7,0.75,0.8,0.85,0.9,0.88,0.82,0.78,0.72,0.68,0.65,0.6,0.58,0.55,0.53,0.5,0.52,0.55,0.58,0.6,0.62,0.58,0.55,0.5,0.48,0.45,0.42,0.4,0.38,0.35,0.32][i];
        return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Container(height: h * 120, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(2))),
        ),      }))),
    const SizedBox(height: 20),
    SwitchListTile(title: const Text('ReplayGain Auto'), value: true, onChanged: (_){}),
    SwitchListTile(title: const Text('Gapless'), value: true, onChanged: (_){}),
  ]));

  void _timer() => showModalBottomSheet(context: context, builder: (_) => ListView(padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
    Text('Minuterie sommeil', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 12),
    ...['15 min','30 min','45 min','60 min','90 min','Fin du morceau'].map((t) =>
      ListTile(title: Text(t), onTap: () => Navigator.pop(context))),
  ]));
}

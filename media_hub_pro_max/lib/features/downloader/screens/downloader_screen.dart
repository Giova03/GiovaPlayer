import 'package:flutter/material.dart';

class DownloaderScreen extends StatefulWidget {
  const DownloaderScreen({super.key});
  @override
  State<DownloaderScreen> createState() => _S();
}
class _S extends State<DownloaderScreen> with TickerProviderStateMixin {
  late TabController _tc;
  final _url = TextEditingController();
  bool _loading = false;
  @override void initState() { super.initState(); _tc = TabController(length: 3, vsync: this); }
  @override void dispose() { _tc.dispose(); _url.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(appBar: AppBar(title: const Text('Downloader'),
      bottom: TabBar(controller: _tc, tabs: const [Tab(text:'Nouveau'), Tab(text:'En cours'), Tab(text:'Termines')])),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: TextField(controller: _url,
          decoration: InputDecoration(hintText: 'Collez un lien YouTube, TikTok, IG...',
            prefixIcon: const Icon(Icons.link),
            suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _analyze),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(28))),
          onSubmitted: (_) => _analyze())),
        Expanded(child: TabBarView(controller: _tc, children: [
          // Nouveau
          ListView(padding: const EdgeInsets.all(16), children: [
            Text('Plateformes', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              Chip(avatar: const Icon(Icons.play_circle, size: 16), label: const Text('YouTube')),
              Chip(avatar: const Icon(Icons.music_note, size: 16), label: const Text('TikTok')),
              Chip(avatar: const Icon(Icons.camera, size: 16), label: const Text('Instagram')),
              Chip(avatar: const Icon(Icons.thumb_up, size: 16), label: const Text('Facebook')),
              Chip(avatar: const Icon(Icons.flutter_dash, size: 16), label: const Text('Twitter/X')),
            ]),
            const SizedBox(height: 20),
            Card(child: ListTile(leading: Icon(Icons.download, color: cs.primary),
              title: const Text('Torrent'), subtitle: const Text('Fichier .torrent ou magnet'), trailing: const Icon(Icons.add))),
          ]),
          // En cours
          ListView(padding: const EdgeInsets.all(16), children: [
            _dl('Film_4K_HDR.mkv', 0.67, '12.4 MB/s', '1.8 / 2.5 GB'),
            _dl('Album_flac.zip', 0.35, '3.2 MB/s', '15 / 45 MB'),
            _dl('Clip_tiktok.mp4', 0.92, '8.1 MB/s', '27 / 30 MB'),
          ]),
          // Termines
          ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
                Text('47', style: Theme.of(context).textTheme.headlineSmall),
                Text('Fichiers', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              ])))),
              Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
                Text('18.5 GB', style: Theme.of(context).textTheme.headlineSmall),
                Text('Total', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              ])))),
            ]),
            ...List.generate(6, (i) => ListTile(
              leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                child: Icon([Icons.movie, Icons.music_note, Icons.image][i%3], color: cs.onSurfaceVariant)),
              title: Text('Fichier_${i+1}'), subtitle: Text('${[2.5,0.5,0.045,1.2,0.8,0.3][i]} GB'),
            )),
          ]),
        ])),
      ]),
    );
  }

  Widget _dl(String t, double p, String s, String sz) => Card(margin: const EdgeInsets.only(bottom: 8),
    child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(t)), Text(s, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600))]),
      const SizedBox(height: 4), Text(sz, style: const TextStyle(fontSize: 12)),
      const SizedBox(height: 8),
      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: p, minHeight: 6)),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('${(p*100).round()}%', style: const TextStyle(fontSize: 12)),
        Row(children: [IconButton(icon: const Icon(Icons.pause, size: 18), onPressed: (){}),
          IconButton(icon: const Icon(Icons.cancel, size: 18), onPressed: (){})]),
      ]),
    ])));

  Future<void> _analyze() async {
    if (_url.text.isEmpty) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _loading = false);
    if (mounted) showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.6, expand: false,
      builder: (c, ctrl) => ListView(controller: ctrl, padding: const EdgeInsets.all(24), children: [
        Text('Formats disponibles', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Text('Video', style: Theme.of(context).textTheme.titleMedium),
        ...['4K (2160p)','1440p','1080p','720p','480p'].map((q) =>
          Card(child: ListTile(title: Text(q), subtitle: Text('MP4 H.${q.contains('4K')?'265':'264'}'),
            trailing: q.startsWith('4K') ? const Icon(Icons.check_circle, color: Colors.blue) : null))),
        const SizedBox(height: 16),
        Text('Audio', style: Theme.of(context).textTheme.titleMedium),
        ...['FLAC','MP3 320k','M4A 256k','OPUS 128k'].map((q) =>
          Card(child: ListTile(title: Text(q)))),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.download), label: const Text('Telecharger'))),
      ])));
  }
}

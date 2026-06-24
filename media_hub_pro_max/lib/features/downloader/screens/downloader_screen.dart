import 'dart:io';
import 'package:flutter/material.dart';

class DownloaderScreen extends StatefulWidget {
  const DownloaderScreen({super.key});
  @override
  State<DownloaderScreen> createState() => _DownloaderScreenState();
}

class _DownloaderScreenState extends State<DownloaderScreen> with TickerProviderStateMixin {
  late TabController _tc;
  final _url = TextEditingController();
  List<File> _files = [];

  @override
  void initState() { super.initState(); _tc = TabController(length: 3, vsync: this); _scan(); }
  @override
  void dispose() { _tc.dispose(); _url.dispose(); super.dispose(); }

  Future<void> _scan() async {
    try {
      final dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) {
        final list = dir.listSync().whereType<File>().toList();
        list.sort((a, b) => b.lastAccessedSync().compareTo(a.lastAccessedSync()));
        setState(() => _files = list);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(appBar: AppBar(title: const Text('Downloader'),
      bottom: TabBar(controller: _tc, tabs: const [Tab(text: 'Nouveau'), Tab(text: 'En cours'), Tab(text: 'Terminés')])),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: TextField(controller: _url,
          decoration: InputDecoration(hintText: 'Collez un lien...', prefixIcon: const Icon(Icons.link),
            suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _analyze),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(28))),
          onSubmitted: (_) => _analyze())),
        Expanded(child: TabBarView(controller: _tc, children: [
          ListView(padding: const EdgeInsets.all(16), children: [
            Text('Plateformes', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8), Wrap(spacing: 8, children: ['YouTube','TikTok','Instagram','Facebook','Twitter/X'].map((p) => Chip(label: Text(p))).toList()),
            const SizedBox(height: 20),
            Card(child: ListTile(leading: Icon(Icons.folder_open, color: cs.primary), title: const Text('Dossier Download'), subtitle: Text('${_files.length} fichiers'), trailing: const Icon(Icons.refresh), onTap: _scan)),
          ]),
          const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.cloud_download, size: 64, color: Colors.grey), SizedBox(height: 16), Text('Aucun téléchargement en cours')])),
          _files.isEmpty ? const Center(child: Text('Aucun fichier')) : ListView.builder(itemCount: _files.length, itemBuilder: (_, i) {
            final f = _files[i]; final name = f.path.substring(f.path.lastIndexOf('/') + 1);
            return ListTile(leading: Icon(Icons.insert_drive_file, color: cs.primary), title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
              subtitle: Text(_fmt(f.lengthSync())));
          }),
        ])),
      ]),
    );
  }

  Future<void> _analyze() async {
    if (_url.text.isEmpty) return;
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) showModalBottomSheet(context: context, builder: (_) => ListView(padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
      Text('Formats', style: Theme.of(context).textTheme.titleLarge),
      ...['1080p MP4', '720p MP4', 'MP3 320k', 'FLAC'].map((q) => Card(child: ListTile(title: Text(q)))),
      const SizedBox(height: 16), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.download), label: const Text('Télécharger'))),
    ]));
  }

  String _fmt(int b) { if (b < 1048576) return '${(b/1024).toStringAsFixed(1)} KB'; return '${(b/1048576).toStringAsFixed(1)} MB'; }
}

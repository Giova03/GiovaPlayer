import os

BASE = "/home/z/my-project/media_hub_pro_max/lib/features"

# ─── GALLERY ───
gallery = r'''import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/file_scanner.dart';
import '../../ia_photo/screens/ia_photo_fix_screen.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});
  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  bool _sel = false;
  final Set<int> _selSet = {};
  bool _showFolders = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(appBar: AppBar(title: _sel ? Text('${_selSet.length} sélectionnée(s)') : const Text('Galerie'),
      actions: [
        IconButton(icon: Icon(_showFolders ? Icons.grid_on : Icons.folder), onPressed: () => setState(() => _showFolders = !_showFolders)),
        IconButton(icon: Icon(_sel ? Icons.close : Icons.select_all), onPressed: () => setState(() { _sel = !_sel; _selSet.clear(); })),
        IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(imageFilesProvider)),
      ]),
      body: ref.watch(imageFilesProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: FilledButton(onPressed: () => ref.invalidate(imageFilesProvider), child: Text('Erreur: $e'))),
        data: (images) {
          if (images.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.photo_library, size: 64, color: cs.onSurfaceVariant.withOpacity(0.5)),
            const SizedBox(height: 16), const Text('Aucune image'),
            const SizedBox(height: 16), FilledButton.icon(onPressed: () => ref.invalidate(imageFilesProvider), icon: const Icon(Icons.refresh), label: const Text('Rescanner')),
          ]));
          return _showFolders ? _folderView(images, cs) : _gridView(images, cs);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IaPhotoFixScreen())),
        icon: const Icon(Icons.auto_fix_high), label: const Text('IA Photo Fix')),
    );
  }

  Widget _folderView(List<MediaFile> images, ColorScheme cs) {
    final scanner = ref.read(fileScannerProvider);
    final folders = scanner.getFilesByFolder('image');
    return ListView(children: [
      Padding(padding: const EdgeInsets.all(12), child: Text('${images.length} images dans ${folders.length} dossiers', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12))),
      ...folders.entries.map((e) => Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: ListTile(
        leading: Container(width: 50, height: 50, decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
          child: e.value.isNotEmpty ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(e.value.first.path), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.folder))) : const Icon(Icons.folder)),
        title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: Text('${e.value.length} images'),
        trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _FolderScreen(name: e.key, images: e.value))),
      ))),
    ]);
  }

  Widget _gridView(List<MediaFile> images, ColorScheme cs) => CustomScrollView(slivers: [
    SliverPadding(padding: const EdgeInsets.all(2), sliver: SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
      delegate: SliverChildBuilderDelegate((ctx, i) => GestureDetector(
        onTap: () { if (_sel) setState(() { _selSet.contains(i) ? _selSet.remove(i) : _selSet.add(i); }); else _showDetail(images, i); },
        onLongPress: () { if (!_sel) setState(() { _sel = true; _selSet.add(i); }); },
        child: Stack(fit: StackFit.expand, children: [
          ClipRRect(borderRadius: BorderRadius.circular(2), child: Image.file(File(images[i].path), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: cs.surfaceContainerHighest, child: const Icon(Icons.broken_image)))),
          if (_sel && _selSet.contains(i)) Positioned(top: 4, right: 4, child: Container(width: 22, height: 22, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.blue), child: const Icon(Icons.check, size: 14, color: Colors.white))),
        ]),
      ), childCount: images.length),
    )),
  ]);

  void _showDetail(List<MediaFile> images, int i) => Navigator.push(context, MaterialPageRoute(builder: (_) => _DetailScreen(images: images, idx: i)));
}

class _FolderScreen extends StatelessWidget {
  final String name; final List<MediaFile> images;
  const _FolderScreen({required this.name, required this.images});
  @override Widget build(BuildContext c) => Scaffold(appBar: AppBar(title: Text(name)), body: GridView.builder(padding: const EdgeInsets.all(2),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2), itemCount: images.length,
    itemBuilder: (_, i) => GestureDetector(onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => _DetailScreen(images: images, idx: i))),
      child: ClipRRect(borderRadius: BorderRadius.circular(2), child: Image.file(File(images[i].path), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey[800])))),
  ));
}

class _DetailScreen extends StatefulWidget {
  final List<MediaFile> images; final int idx;
  const _DetailScreen({required this.images, required this.idx});
  @override State<_DetailScreen> createState() => _DetailScreenState();
}
class _DetailScreenState extends State<_DetailScreen> {
  late PageController _pc; late int _cur;
  @override void initState() { super.initState(); _cur = widget.idx; _pc = PageController(initialPage: _cur); }
  @override void dispose() { _pc.dispose(); super.dispose(); }
  @override Widget build(BuildContext c) {
    final img = widget.images[_cur];
    return Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white,
      title: Text(img.displayName, style: const TextStyle(fontSize: 13))),
      body: PageView.builder(controller: _pc, itemCount: widget.images.length, onPageChanged: (i) => setState(() => _cur = i),
        itemBuilder: (_, i) => InteractiveViewer(minScale: 0.5, maxScale: 5.0, child: Center(child: Image.file(File(widget.images[i].path), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 64, color: Colors.white54)))),
      ),
    );
  }
}
'''

ia_photo = r'''import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/file_scanner.dart';

class IaPhotoFixScreen extends ConsumerStatefulWidget {
  const IaPhotoFixScreen({super.key});
  @override
  ConsumerState<IaPhotoFixScreen> createState() => _IaPhotoFixScreenState();
}

class _IaPhotoFixScreenState extends ConsumerState<IaPhotoFixScreen> {
  MediaFile? _selectedImage;
  double _brightness = 0.0;
  double _contrast = 0.0;
  double _saturation = 1.0;
  double _sepia = 0.0;
  bool _proMode = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final images = ref.watch(imageFilesProvider).valueOrNull ?? [];
    return Scaffold(appBar: AppBar(title: const Text('IA Photo Fix')), body: Column(children: [
      Expanded(flex: 3, child: Container(color: Colors.black, child: _selectedImage == null
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.add_photo_alternate, size: 64, color: Colors.white54), const SizedBox(height: 12), const Text('Sélectionnez une image', style: TextStyle(color: Colors.white54))]))
        : ColorFiltered(colorFilter: ColorFilter.matrix(_colorMatrix), child: Center(child: Image.file(File(_selectedImage!.path), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 64, color: Colors.white54)))))),
      Expanded(flex: 2, child: SingleChildScrollView(child: Column(children: [
        if (_selectedImage == null) SizedBox(height: 80, child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(8),
          itemCount: min(images.length, 30), itemBuilder: (_, i) => GestureDetector(onTap: () => setState(() => _selectedImage = images[i]),
            child: Container(width: 70, height: 70, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: cs.outline)),
              child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(images[i].path), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image))))))),
        if (_selectedImage != null) ...[
          Padding(padding: const EdgeInsets.all(8), child: Row(children: [
            Expanded(child: Text(_selectedImage!.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
            TextButton(onPressed: () => setState(() => _selectedImage = null), child: const Text('Changer')),
          ])),
          SegmentedButton(segments: const [ButtonSegment(value: false, label: Text('Auto')), ButtonSegment(value: true, label: Text('Pro'))],
            selected: {_proMode}, onSelectionChanged: (v) => setState(() => _proMode = v.first)),
          _sl('Luminosité', _brightness, -1, 1, (v) => setState(() => _brightness = v)),
          _sl('Contraste', _contrast, -1, 1, (v) => setState(() => _contrast = v)),
          _sl('Saturation', _saturation, 0, 2, (v) => setState(() => _saturation = v)),
          if (_proMode) _sl('Sepia', _sepia, 0, 1, (v) => setState(() => _sepia = v)),
          Padding(padding: const EdgeInsets.all(12), child: Row(children: [
            Expanded(child: FilledButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Filtre appliqué !'))), icon: const Icon(Icons.check), label: const Text('Appliquer'))),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: _reset, child: const Text('Reset')),
          ])),
        ],
      ]))),
    ]));
  }

  Widget _sl(String l, double v, double mn, double mx, ValueChanged<double> cb) => Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    child: Row(children: [SizedBox(width: 90, child: Text(l, style: const TextStyle(fontSize: 12))), Expanded(child: Slider(value: v, min: mn, max: mx, onChanged: cb))]));

  List<double> _colorMatrix => [
    (1 + _contrast) * (_saturation + _sepia * 0.3), _sepia * 0.7, _sepia * 0.2, 0, _brightness * 255,
    _sepia * 0.2, (1 + _contrast) * _saturation, _sepia * 0.1, 0, _brightness * 255,
    _sepia * 0.1, _sepia * 0.3, (1 + _contrast) * (_saturation + _sepia * 0.6), 0, _brightness * 255,
    0, 0, 0, 1, 0,
  ];

  void _reset() => setState(() { _selectedImage = null; _brightness = 0; _contrast = 0; _saturation = 1; _sepia = 0; });
}
'''

downloader = r'''import 'dart:io';
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
'''

for name, content, path in [
  ('gallery', gallery, f'{BASE}/gallery/screens/gallery_screen.dart'),
  ('ia_photo', ia_photo, f'{BASE}/ia_photo/screens/ia_photo_fix_screen.dart'),
  ('downloader', downloader, f'{BASE}/downloader/screens/downloader_screen.dart'),
]:
  os.makedirs(os.path.dirname(path), exist_ok=True)
  with open(path, 'w') as f:
    f.write(content)
  print(f"Written {name}")
print("Done")

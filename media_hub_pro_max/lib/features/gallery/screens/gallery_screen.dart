import 'dart:io';
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
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(appBar: AppBar(title: _sel ? Text('${_selSet.length} sélectionnée(s)') : const Text('Galerie'),
      actions: [
        IconButton(icon: Icon(_showFolders ? Icons.grid_on : Icons.folder), onPressed: () => setState(() => _showFolders = !_showFolders)),
        IconButton(icon: Icon(_sel ? Icons.close : Icons.select_all), onPressed: () => setState(() { _sel = !_sel; _selSet.clear(); })),
        IconButton(icon: const Icon(Icons.refresh), onPressed: () async => forceRescanAll(ref)),
      ]),
      body: ref.watch(imageFilesProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: FilledButton(onPressed: () => forceRescanAll(ref), child: Text('Erreur: $e'))),
        data: (images) {
          final filtered = _search.isEmpty ? images : images.where((f) => f.displayName.toLowerCase().contains(_search.toLowerCase())).toList();
          if (filtered.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.photo_library, size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 16), const Text('Aucune image'),
            const SizedBox(height: 16), FilledButton.icon(onPressed: () => forceRescanAll(ref), icon: const Icon(Icons.refresh), label: const Text('Rescanner')),
          ]));
          return Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 4), child: TextField(decoration: InputDecoration(
              hintText: 'Rechercher...', prefixIcon: const Icon(Icons.search, size: 20), isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
            ), onChanged: (v) => setState(() => _search = v))),
            Expanded(child: _showFolders ? _folderView(filtered, cs) : _gridView(filtered, cs)),
          ]);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IaPhotoFixScreen())),
        icon: const Icon(Icons.auto_fix_high), label: const Text('IA Photo Fix')),
    );
  }

  Widget _folderView(List<MediaFile> images, ColorScheme cs) {
    final scanner = ref.read(fileScannerProvider);
    final folders = scanner.getFilesByFolder('image');
    // Filter folders by search
    final filteredFolders = _search.isEmpty ? folders : Map.fromEntries(folders.entries.where((e) => e.key.toLowerCase().contains(_search.toLowerCase()) || e.value.any((f) => f.displayName.toLowerCase().contains(_search.toLowerCase()))));
    return ListView(children: [
      Padding(padding: const EdgeInsets.all(12), child: Text('${images.length} images dans ${filteredFolders.length} dossiers', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12))),
      ...filteredFolders.entries.map((e) => Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: ListTile(
        leading: Container(width: 50, height: 50, decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
          child: e.value.isNotEmpty ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(e.value.first.path), fit: BoxFit.cover, cacheWidth: 100, errorBuilder: (_, __, ___) => const Icon(Icons.folder))) : const Icon(Icons.folder)),
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
          ClipRRect(borderRadius: BorderRadius.circular(2), child: Image.file(File(images[i].path), fit: BoxFit.cover, cacheWidth: 300, errorBuilder: (_, __, ___) => Container(color: cs.surfaceContainerHighest, child: const Icon(Icons.broken_image)))),
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
      child: ClipRRect(borderRadius: BorderRadius.circular(2), child: Image.file(File(images[i].path), fit: BoxFit.cover, cacheWidth: 300, errorBuilder: (_, __, ___) => Container(color: Colors.grey[800])))),
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
        itemBuilder: (_, i) => InteractiveViewer(minScale: 0.5, maxScale: 5.0, child: Center(child: Image.file(File(widget.images[i].path), fit: BoxFit.contain, cacheWidth: 1080, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 64, color: Colors.white54)))),
      ),
    );
  }
}

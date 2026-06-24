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
  String _searchQuery = '';
  bool _showFolders = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final imageFilesAsync = ref.watch(imageFilesProvider);

    return Scaffold(
      appBar: AppBar(
        title: _sel ? Text('${_selSet.length} sélectionnée(s)') : const Text('Galerie'),
        actions: [
          IconButton(icon: Icon(_showFolders ? Icons.grid_on : Icons.folder),
            onPressed: () => setState(() => _showFolders = !_showFolders), tooltip: 'Vue'),
          IconButton(icon: const Icon(Icons.search), onPressed: () => showSearch(context: context, delegate: _Search(ref))),
          IconButton(icon: Icon(_sel ? Icons.close : Icons.select_all),
            onPressed: () => setState(() { _sel = !_sel; _selSet.clear(); })),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(imageFilesProvider)),
        ],
      ),
      body: imageFilesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.error_outline, size: 64, color: cs.error),
          const SizedBox(height: 16), Text('$e', textAlign: TextAlign.center),
          const SizedBox(height: 16), FilledButton.icon(onPressed: () => ref.invalidate(imageFilesProvider),
            icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
        ])),
        data: (images) {
          if (images.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.photo_library, size: 64, color: cs.onSurfaceVariant.withOpacity(0.5)),
            const SizedBox(height: 16), const Text('Aucune image trouvée'),
            const SizedBox(height: 16), FilledButton.icon(onPressed: () => ref.invalidate(imageFilesProvider),
              icon: const Icon(Icons.refresh), label: const Text('Rescanner')),
          ]));
          return _showFolders ? _buildFolderView(images, cs) : _buildGridView(images, cs);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IaPhotoFixScreen())),
        icon: const Icon(Icons.auto_fix_high), label: const Text('IA Photo Fix')),
    );
  }

  Widget _buildFolderView(List<MediaFile> images, ColorScheme cs) {
    final scanner = ref.read(fileScannerProvider);
    final folders = scanner.getFilesByFolder('image');
    return ListView(children: [
      // Stats
      Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        Text('${images.length} images dans ${folders.length} dossiers',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        const Spacer(),
        TextButton(onPressed: () => setState(() => _showFolders = false),
          child: const Text('Vue grille')),
      ])),
      // Dossiers
      ...folders.entries.map((entry) => Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: ListTile(
          leading: Container(width: 56, height: 56,
            decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
            child: entry.value.isNotEmpty
              ? ClipRRect(borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(entry.value.first.path), fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.folder)))
              : const Icon(Icons.folder)),
          title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${entry.value.length} images'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => _FolderImagesScreen(folderName: entry.key, images: entry.value))),
        ))),
    ]);
  }

  Widget _buildGridView(List<MediaFile> images, ColorScheme cs) {
    final filtered = _searchQuery.isEmpty ? images : images.where((i) =>
      i.displayName.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(8),
        child: Row(children: [
          Text('${filtered.length} images', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          const Spacer(),
          TextButton(onPressed: () => setState(() => _showFolders = true), child: const Text('Dossiers')),
        ]))),
      SliverPadding(padding: const EdgeInsets.all(2), sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
        delegate: SliverChildBuilderDelegate((ctx, i) {
          final img = filtered[i];
          return GestureDetector(
            onTap: () {
              if (_sel) { setState(() { _selSet.contains(i) ? _selSet.remove(i) : _selSet.add(i); }); }
              else { _showImageDetail(img, i, filtered); }
            },
            onLongPress: () { if (!_sel) setState(() { _sel = true; _selSet.add(i); }); },
            child: Stack(fit: StackFit.expand, children: [
              ClipRRect(borderRadius: BorderRadius.circular(2),
                child: Image.file(File(img.path), fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: cs.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image)))),
              if (_sel && _selSet.contains(i)) Positioned(top: 4, right: 4, child: Container(width: 22, height: 22,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.blue),
                child: const Icon(Icons.check, size: 14, color: Colors.white))),
            ]),
          );
        }, childCount: filtered.length),
      )),
    ]);
  }

  void _showImageDetail(MediaFile img, int index, List<MediaFile> allImages) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _ImageDetailScreen(
      images: allImages, initialIndex: index)));
  }
}

// ═══ Dossier d'images ═══
class _FolderImagesScreen extends StatelessWidget {
  final String folderName;
  final List<MediaFile> images;
  const _FolderImagesScreen({required this.folderName, required this.images});

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text(folderName)),
      body: GridView.builder(padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
        itemCount: images.length,
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => _ImageDetailScreen(images: images, initialIndex: i))),
          child: ClipRRect(borderRadius: BorderRadius.circular(2),
            child: Image.file(File(images[i].path), fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.grey[800]))),
        ),
      ),
    );
  }
}

// ═══ Détail image plein écran ═══
class _ImageDetailScreen extends StatefulWidget {
  final List<MediaFile> images;
  final int initialIndex;
  const _ImageDetailScreen({required this.images, required this.initialIndex});
  @override
  State<_ImageDetailScreen> createState() => _ImageDetailScreenState();
}

class _ImageDetailScreenState extends State<_ImageDetailScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() { _pageController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final img = widget.images[_currentIndex];
    return Scaffold(backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white,
        title: Text(img.displayName, style: const TextStyle(fontSize: 14)),
        actions: [
          IconButton(icon: const Icon(Icons.share), onPressed: (){}),
          IconButton(icon: const Icon(Icons.edit), onPressed: (){}),
          IconButton(icon: const Icon(Icons.delete), onPressed: (){}),
          IconButton(icon: const Icon(Icons.info), onPressed: () => _showInfo(img)),
        ]),
      body: PageView.builder(controller: _pageController, itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (_, i) => InteractiveViewer(minScale: 0.5, maxScale: 5.0,
          child: Center(child: Image.file(File(widget.images[i].path), fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 64, color: Colors.white54))),
      ),
    );
  }

  void _showInfo(MediaFile img) => showModalBottomSheet(context: context, builder: (_) => ListView(
    padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
    Text('Informations', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 12),
    _infoRow('Nom', img.displayName),
    _infoRow('Chemin', img.path),
    _infoRow('Taille', img.sizeFormatted),
    _infoRow('Type', img.extension.toUpperCase()),
    _infoRow('Modifié', '${img.modified.day}/${img.modified.month}/${img.modified.year}'),
  ]));

  Widget _infoRow(String l, String v) => Padding(padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 80, child: Text(l, style: const TextStyle(fontWeight: FontWeight.w600))),
      Expanded(child: Text(v, style: const TextStyle(fontSize: 13))),
    ]));
}

class _Search extends SearchDelegate<String> {
  final WidgetRef ref;
  _Search(this.ref);

  @override
  List<Widget> buildActions(BuildContext c) => [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];
  @override
  Widget buildLeading(BuildContext c) => IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(c, ''));
  @override
  Widget buildResults(BuildContext c) => _buildResults(c);
  @override
  Widget buildSuggestions(BuildContext c) => query.isEmpty ? const Center(child: Text('Rechercher des images')) : _buildResults(c);

  Widget _buildResults(BuildContext c) {
    final images = ref.read(imageFilesProvider).valueOrNull ?? [];
    final filtered = images.where((i) => i.displayName.toLowerCase().contains(query.toLowerCase())).toList();
    return GridView.count(crossAxisCount: 3, shrinkWrap: true,
      children: filtered.map((img) => Image.file(File(img.path), fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: Colors.grey[800]))).toList());
  }
}

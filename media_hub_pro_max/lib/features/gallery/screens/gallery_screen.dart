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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final imageFilesAsync = ref.watch(imageFilesProvider);

    return Scaffold(
      appBar: AppBar(
        title: _sel ? Text('${_selSet.length} sélectionnée(s)') : const Text('Galerie IA'),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () => showSearch(context: context, delegate: _Search(ref))),
          IconButton(icon: const Icon(Icons.auto_awesome), onPressed: _aiSort),
          IconButton(icon: Icon(_sel ? Icons.close : Icons.select_all),
            onPressed: () => setState(() { _sel = !_sel; _selSet.clear(); })),
        ],
      ),
      body: imageFilesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.error_outline, size: 64, color: cs.error),
          const SizedBox(height: 16),
          Text('Erreur: $e', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: () => ref.invalidate(imageFilesProvider),
            icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
        ])),
        data: (images) {
          if (images.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.photo_library, size: 64, color: cs.onSurfaceVariant.withOpacity(0.5)),
              const SizedBox(height: 16),
              const Text('Aucune image trouvée'),
              const SizedBox(height: 8),
              Text('Vérifiez les permissions', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: () => ref.invalidate(imageFilesProvider),
                icon: const Icon(Icons.refresh), label: const Text('Rescanner')),
            ]));
          }
          return CustomScrollView(slivers: [
            // Barre d'actions IA
            SliverToBoxAdapter(child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: cs.primaryContainer.withOpacity(0.3),
              child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                ActionChip(avatar: const Icon(Icons.auto_fix_high, size: 16), label: const Text('IA Photo Fix'), onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const IaPhotoFixScreen()));
                }),
                const SizedBox(width: 8),
                ActionChip(avatar: const Icon(Icons.content_copy, size: 16), label: Text('${images.length} images'), onPressed: (){}),
                const SizedBox(width: 8),
                ActionChip(avatar: const Icon(Icons.sort, size: 16), label: const Text('Trier'), onPressed: _sortMenu),
              ])))),
            // Grille d'images
            SliverPadding(padding: const EdgeInsets.all(4), sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
              delegate: SliverChildBuilderDelegate((ctx, i) {
                final img = images[i];
                return GestureDetector(
                  onTap: () {
                    if (_sel) {
                      setState(() { _selSet.contains(i) ? _selSet.remove(i) : _selSet.add(i); });
                    } else {
                      _showImageDetail(img, i, images);
                    }
                  },
                  onLongPress: () {
                    if (!_sel) setState(() { _sel = true; _selSet.add(i); });
                  },
                  child: Stack(fit: StackFit.expand, children: [
                    ClipRRect(borderRadius: BorderRadius.circular(2),
                      child: Image.file(File(img.path), fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: cs.surfaceContainerHighest,
                          child: Icon(Icons.broken_image, color: cs.onSurfaceVariant)))),
                    if (_sel && _selSet.contains(i)) Positioned(top: 4, right: 4, child: Container(width: 22, height: 22,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.blue),
                      child: const Icon(Icons.check, size: 14, color: Colors.white))),
                  ]),
                );
              }, childCount: images.length),
            )),
          ]);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IaPhotoFixScreen())),
        icon: const Icon(Icons.auto_fix_high), label: const Text('IA Photo Fix')),
    );
  }

  void _showImageDetail(MediaFile img, int index, List<MediaFile> allImages) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _ImageDetailScreen(
      images: allImages, initialIndex: index,
    )));
  }

  void _sortMenu() => showModalBottomSheet(context: context, builder: (_) => ListView(
    padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
    Text('Trier par', style: Theme.of(context).textTheme.titleLarge),
    ...[(Icons.access_time, 'Date récente'), (Icons.schedule, 'Date ancienne'),
      (Icons.sort_by_alpha, 'Nom A-Z'), (Icons.text_rotate_vertical, 'Nom Z-A'),
      (Icons.sd_card, 'Taille ↓'), (Icons.sd_card_outlined, 'Taille ↑')].map((t) =>
      ListTile(leading: Icon(t.$1, color: Theme.of(context).colorScheme.primary),
        title: Text(t.$2), onTap: () => Navigator.pop(context))),
  ]));

  void _aiSort() => showModalBottomSheet(context: context, builder: (_) => ListView(
    padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
    Text('Tri IA', style: Theme.of(context).textTheme.titleLarge),
    ...[(Icons.folder, 'Dossiers', 'Par répertoire source'),
      (Icons.photo_size_select_large, 'Taille', 'Grandes en premier'),
      (Icons.content_copy, 'Doublons', 'Trouver les similaires'),
      (Icons.blur_on, 'Floues', 'Images de mauvaise qualité')].map((t) =>
      ListTile(leading: Icon(t.$1, color: Theme.of(context).colorScheme.primary),
        title: Text(t.$2), subtitle: Text(t.$3))),
  ]));
}

// ─── Détail image plein écran ───
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
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final img = widget.images[_currentIndex];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white,
        title: Text(img.displayName, style: const TextStyle(fontSize: 14)),
        actions: [
          IconButton(icon: const Icon(Icons.share), onPressed: (){}),
          IconButton(icon: const Icon(Icons.delete), onPressed: (){}),
          IconButton(icon: const Icon(Icons.info), onPressed: () => _showInfo(img)),
        ]),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (_, i) => InteractiveViewer(
          minScale: 0.5, maxScale: 4.0,
          child: Center(child: Image.file(File(widget.images[i].path), fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 64, color: Colors.white54))),
        ),
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

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 80, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
    ]),
  );
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
  Widget buildSuggestions(BuildContext c) => query.isEmpty
    ? Center(child: Text('Tapez pour rechercher des images'))
    : _buildResults(c);

  Widget _buildResults(BuildContext c) {
    final images = ref.read(imageFilesProvider).valueOrNull ?? [];
    final filtered = images.where((i) => i.displayName.toLowerCase().contains(query.toLowerCase())).toList();
    return GridView.count(crossAxisCount: 3, shrinkWrap: true,
      children: filtered.map((img) => Image.file(File(img.path), fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: Colors.grey[800]))).toList());
  }
}

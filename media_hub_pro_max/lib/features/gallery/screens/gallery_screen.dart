import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ia_photo/screens/ia_photo_fix_screen.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});
  @override
  ConsumerState<GalleryScreen> createState() => _S();
}
class _S extends ConsumerState<GalleryScreen> {
  bool _sel = false;
  final Set<int> _selSet = {};

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(appBar: AppBar(title: _sel ? Text('${_selSet.length} selectionnee(s)') : const Text('Galerie IA'),
      actions: [
        IconButton(icon: const Icon(Icons.search), onPressed: () => showSearch(context: context, delegate: _Search())),
        IconButton(icon: const Icon(Icons.auto_awesome), onPressed: _aiSort),
        IconButton(icon: Icon(_sel ? Icons.close : Icons.select_all),
          onPressed: () => setState(() { _sel = !_sel; _selSet.clear(); })),
      ]),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: cs.primaryContainer.withValues(alpha:0.3),
          child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            ActionChip(avatar: const Icon(Icons.auto_fix_high, size: 16), label: const Text('3 photos a corriger'), onPressed: (){}),
            const SizedBox(width: 8),
            ActionChip(avatar: const Icon(Icons.content_copy, size: 16), label: const Text('15 doublons'), onPressed: (){}),
            const SizedBox(width: 8),
            ActionChip(avatar: const Icon(Icons.face, size: 16), label: const Text('Visages detectes'), onPressed: (){}),
          ])))),
        SliverPadding(padding: const EdgeInsets.all(4), sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
          delegate: SliverChildBuilderDelegate((ctx, i) => GestureDetector(
            onTap: () { if (_sel) setState(() { _selSet.contains(i) ? _selSet.remove(i) : _selSet.add(i); }); },
            onLongPress: () { if (!_sel) setState(() { _sel = true; _selSet.add(i); }); },
            child: Stack(fit: StackFit.expand, children: [
              Container(color: Color.lerp(cs.surfaceContainerHighest, cs.primary, (i%7)*0.05),
                child: Icon(Icons.photo, color: cs.onSurfaceVariant.withValues(alpha:0.5))),
              if (_sel && _selSet.contains(i)) Positioned(top: 4, right: 4, child: Container(width: 22, height: 22,
                decoration: BoxDecoration(shape: BoxShape.circle, color: cs.primary),
                child: const Icon(Icons.check, size: 14, color: Colors.white))),
            ]),
          ), childCount: 30),
        )),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IaPhotoFixScreen())),
        icon: const Icon(Icons.auto_fix_high), label: const Text('IA Photo Fix')),
    );
  }

  void _aiSort() => showModalBottomSheet(context: context, builder: (_) => ListView(padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
    Text('Tri IA', style: Theme.of(context).textTheme.titleLarge),
    ...[(Icons.face,'Visages','42 photos'),(Icons.place,'Lieux GPS','8 lieux'),(Icons.category,'Objets','Chat, Voiture...'),
      (Icons.emoji_emotions,'Emotions','Heureux, Sérieux'),(Icons.text_fields,'Texte OCR','12 photos'),
      (Icons.content_copy,'Doublons','15 trouves'),(Icons.blur_on,'Floues','8 a supprimer')].map((t) =>
      ListTile(leading: Icon(t.$1, color: Theme.of(context).colorScheme.primary), title: Text(t.$2), subtitle: Text(t.$3))),
  ]));
}

class _Search extends SearchDelegate<String> {
  @override List<Widget> buildActions(BuildContext c) => [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];
  @override Widget buildLeading(BuildContext c) => IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(c, ''));
  @override Widget buildResults(BuildContext c) => _res(c);
  @override Widget buildSuggestions(BuildContext c) => query.isEmpty ? ListView(padding: const EdgeInsets.all(24), children: [
    Text('Recherche semantique IA', style: Theme.of(c).textTheme.titleMedium),
    const SizedBox(height: 12),
    ...['photo moi en costume 2022 plage','chat noir sur canape','photos coucher du soleil'].map((q) =>
      Padding(padding: const EdgeInsets.only(bottom: 8), child: ActionChip(avatar: const Icon(Icons.auto_awesome, size: 16), label: Text(q), onPressed: (){}))),
  ]): _res(c);

  Widget _res(BuildContext c) => GridView.count(crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
    children: List.generate(6, (_) => Container(color: Theme.of(c).colorScheme.surfaceContainerHighest, child: const Icon(Icons.photo, color: Colors.grey))));
}

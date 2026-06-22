import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ─── ÉCRAN GALERIE + IA PHOTO ───
/// Features: Tri IA, Recherche sémantique, Éditeur 1-clic,
/// Suppression objet, Change fond/tenue, Collage auto,
/// Scan documents, Doublons, Album Coffré
class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  bool _isSelectMode = false;
  final Set<int> _selectedIndices = {};
  String _viewMode = 'grid'; // grid | list | categories

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: _isSelectMode
            ? Text('${_selectedIndices.length} sélectionnée(s)')
            : const Text('Galerie IA'),
        actions: [
          /// Recherche sémantique
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSemanticSearch,
          ),
          /// Tri IA
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: _showAiSort,
          ),
          /// Basculer vue
          IconButton(
            icon: Icon(_viewMode == 'grid'
                ? Icons.grid_view
                : _viewMode == 'list'
                    ? Icons.view_list
                    : Icons.category),
            onPressed: _cycleViewMode,
          ),
          /// Sélection multiple
          IconButton(
            icon: Icon(_isSelectMode ? Icons.close : Icons.select_all),
            onPressed: () => setState(() {
              _isSelectMode = !_isSelectMode;
              _selectedIndices.clear();
            }),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          /// Bandeau IA suggestions
          SliverToBoxAdapter(
            child: _AiInsightBar(),
          ),

          /// Grille photos
          SliverPadding(
            padding: const EdgeInsets.all(4),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _PhotoTile(
                  index: index,
                  isSelected: _selectedIndices.contains(index),
                  isSelectMode: _isSelectMode,
                  onTap: () => _onPhotoTap(index),
                  onLongPress: () => _onPhotoLongPress(index),
                ),
                childCount: 30,
              ),
            ),
          ),
        ],
      ),

      /// FAB — accès rapide IA Photo Fix
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToIaPhotoFix(),
        icon: const Icon(Icons.auto_fix_high),
        label: const Text('IA Photo Fix'),
      ),

      /// Barre d'actions si sélection
      bottomNavigationBar: _isSelectMode
          ? _SelectionActionBar(
              count: _selectedIndices.length,
              onIaFix: () => _navigateToIaPhotoFix(),
              onDelete: _deleteSelected,
              onVault: _moveToVault,
              onShare: _shareSelected,
            )
          : null,
    );
  }

  /// Navigation vers l'écran IA Photo Fix
  void _navigateToIaPhotoFix() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const IaPhotoFixScreen(),
      ),
    );
  }

  void _onPhotoTap(int index) {
    if (_isSelectMode) {
      setState(() {
        if (_selectedIndices.contains(index)) {
          _selectedIndices.remove(index);
        } else {
          _selectedIndices.add(index);
        }
      });
    } else {
      /// Ouvrir visionneuse plein écran
    }
  }

  void _onPhotoLongPress(int index) {
    if (!_isSelectMode) {
      setState(() {
        _isSelectMode = true;
        _selectedIndices.add(index);
      });
    }
  }

  void _cycleViewMode() {
    setState(() {
      _viewMode = switch (_viewMode) {
        'grid' => 'list',
        'list' => 'categories',
        _ => 'grid',
      };
    });
  }

  /// Recherche sémantique : "photo moi en costume 2022 plage"
  void _showSemanticSearch() {
    showSearch(
      context: context,
      delegate: _SemanticSearchDelegate(),
    );
  }

  /// Tri IA par catégories
  void _showAiSort() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView(
        padding: const EdgeInsets.all(24),
        shrinkWrap: true,
        children: [
          Text('Tri IA', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _SortChip('Visages', Icons.face, '42 photos avec visages'),
          _SortChip('Lieux GPS', Icons.place, '8 lieux identifiés'),
          _SortChip('Objets', Icons.category, 'Chat, Voiture, Nourriture...'),
          _SortChip('Émotions', Icons.emoji_emotions, 'Heureux, Sérieux...'),
          _SortChip('Texte OCR', Icons.text_fields, '12 photos avec texte'),
          _SortChip('Date', Icons.calendar_today, 'Chronologique'),
          const Divider(),
          _SortChip('Doublons', Icons.content_copy, '15 doublons détectés'),
          _SortChip('Photos floues', Icons.blur_on, '8 floues à supprimer'),
        ],
      ),
    );
  }

  void _deleteSelected() {}
  void _moveToVault() {}
  void _shareSelected() {}
}

/// ─── BARRE INSIGHTS IA ───
class _AiInsightBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: cs.primaryContainer.withOpacity(0.3),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ActionChip(
              avatar: const Icon(Icons.auto_fix_high, size: 16),
              label: const Text('3 photos à corriger'),
              onPressed: () {},
            ),
            const SizedBox(width: 8),
            ActionChip(
              avatar: const Icon(Icons.content_copy, size: 16),
              label: const Text('15 doublons'),
              onPressed: () {},
            ),
            const SizedBox(width: 8),
            ActionChip(
              avatar: const Icon(Icons.face, size: 16),
              label: const Text('Nouveau visage détecté'),
              onPressed: () {},
            ),
            const SizedBox(width: 8),
            ActionChip(
              avatar: const Icon(Icons.lock, size: 16),
              label: const Text('Coffrer 3 photos'),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}

/// ─── TUILE PHOTO ───
class _PhotoTile extends StatelessWidget {
  final int index;
  final bool isSelected;
  final bool isSelectMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PhotoTile({
    required this.index,
    required this.isSelected,
    required this.isSelectMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          /// Image placeholder
          Container(
            color: Color.lerp(
              cs.surfaceContainerHighest,
              cs.primary,
              (index % 7) * 0.05,
            ),
            child: Center(
              child: Icon(
                Icons.photo,
                color: cs.onSurfaceVariant.withOpacity(0.5),
              ),
            ),
          ),

          /// Indicateur sélection
          if (isSelectMode)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? cs.primary
                      : Colors.white.withOpacity(0.7),
                  border: Border.all(
                    color: isSelected ? cs.primary : Colors.grey,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

/// ─── BARRE D'ACTIONS SÉLECTION ───
class _SelectionActionBar extends StatelessWidget {
  final int count;
  final VoidCallback onIaFix;
  final VoidCallback onDelete;
  final VoidCallback onVault;
  final VoidCallback onShare;

  const _SelectionActionBar({
    required this.count,
    required this.onIaFix,
    required this.onDelete,
    required this.onVault,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ActionButton(Icons.auto_fix_high, 'IA Fix', onIaFix, cs.primary),
          _ActionButton(Icons.lock, 'Coffrer', onVault, cs.tertiary),
          _ActionButton(Icons.share, 'Partager', onShare, cs.secondary),
          _ActionButton(Icons.delete, 'Supprimer', onDelete, cs.error),
        ],
      ),
    );
  }

  Widget _ActionButton(IconData icon, String label, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

/// ─── RECHERCHE SÉMANTIQUE ───
class _SemanticSearchDelegate extends SearchDelegate<String> {
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _SearchResults(query: query);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Recherche sémantique IA', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Text('Exemples :', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          _SuggestionChip('photo moi en costume 2022 plage'),
          _SuggestionChip('chat noir sur canapé'),
          _SuggestionChip('capture d\'écran réunion'),
          _SuggestionChip('photos au coucher du soleil'),
          _SuggestionChip('documents avec texte'),
        ],
      );
    }
    return _SearchResults(query: query);
  }
}

class _SuggestionChip extends StatelessWidget {
  final String text;
  const _SuggestionChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ActionChip(
        icon: const Icon(Icons.auto_awesome, size: 16),
        label: Text(text),
        onPressed: () {},
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  final String query;
  const _SearchResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Résultats pour "$query"',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text('Recherche IA en cours... Analyse visuelle + texte + métadonnées',
            style: TextStyle(color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: 6,
          itemBuilder: (context, i) => Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Icon(Icons.photo, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}

/// ─── PUCE DE TRI ───
class _SortChip extends StatelessWidget {
  final String title;
  final IconData icon;
  final String subtitle;

  const _SortChip(this.title, this.icon, this.subtitle);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.pop(context),
    );
  }
}

/// Import nécessaire pour la navigation
import '../../ia_photo/screens/ia_photo_fix_screen.dart';

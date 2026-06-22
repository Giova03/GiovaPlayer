// GiovaPlayer - Galerie photo avec tri IA
// Contact: giobamos03@gmail.com | WhatsApp: +22670698070
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ia_photo/screens/ia_photo_fix_screen.dart';
import '../../../core/providers/app_providers.dart';

/// Ecran de la galerie photo GiovaPlayer
class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  bool _isMultiSelect = false;
  final Set<int> _selectedIndices = {};
  String _activeSort = 'Tout';

  final List<_SortChip> _sortChips = [
    _SortChip('Tout', Icons.photo_library),
    _SortChip('Visages', Icons.face),
    _SortChip('Objets', Icons.category),
    _SortChip('OCR', Icons.text_fields),
    _SortChip('Emotions', Icons.sentiment_satisfied),
    _SortChip('GPS', Icons.location_on),
    _SortChip('Doublons', Icons.content_copy),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: _isMultiSelect
            ? Text('${_selectedIndices.length} selectionne(s)')
            : const Text('Galerie'),
        actions: _buildAppBarActions(),
      ),
      body: Column(
        children: [
          _buildSortChips(cs),
          Expanded(child: _buildPhotoGrid(cs)),
        ],
      ),
      floatingActionButton: _buildFab(cs),
    );
  }

  /// Actions de l'AppBar selon le mode
  List<Widget> _buildAppBarActions() {
    if (_isMultiSelect) {
      return [
        IconButton(
          onPressed: () => setState(() {
            _isMultiSelect = false;
            _selectedIndices.clear();
          }),
          icon: const Icon(Icons.close),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.delete_outline),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.lock_outline),
        ),
      ];
    }
    return [
      IconButton(
        onPressed: () => showSearch(
          context: context,
          delegate: _SemanticSearchDelegate(),
        ),
        icon: const Icon(Icons.search),
      ),
      IconButton(
        onPressed: () {},
        icon: const Icon(Icons.sort),
      ),
    ];
  }

  /// Chips de tri IA
  Widget _buildSortChips(ColorScheme cs) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _sortChips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final chip = _sortChips[i];
          final isActive = _activeSort == chip.label;
          return FilterChip(
            selected: isActive,
            avatar: Icon(chip.icon, size: 16),
            label: Text(chip.label),
            onSelected: (_) => setState(() => _activeSort = chip.label),
          );
        },
      ),
    );
  }

  /// Grille de photos
  Widget _buildPhotoGrid(ColorScheme cs) {
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: 30,
      itemBuilder: (_, i) => _buildPhotoItem(cs, i),
    );
  }

  /// Element de photo individuelle
  Widget _buildPhotoItem(ColorScheme cs, int index) {
    final isSelected = _selectedIndices.contains(index);
    return GestureDetector(
      onLongPress: () => _toggleMultiSelect(index),
      onTap: () {
        if (_isMultiSelect) {
          _toggleMultiSelect(index);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: cs.surfaceContainerHighest,
            child: Icon(Icons.image, color: cs.onSurfaceVariant, size: 36),
          ),
          if (isSelected)
            Container(
              color: cs.primary.withValues(alpha: 0.3),
              child: Icon(Icons.check_circle, color: cs.primary, size: 32),
            ),
          if (_isMultiSelect && !isSelected)
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Icon(Icons.radio_button_unchecked,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
            ),
        ],
      ),
    );
  }

  /// Bascule la selection multiple
  void _toggleMultiSelect(int index) {
    setState(() {
      _isMultiSelect = true;
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
        if (_selectedIndices.isEmpty) _isMultiSelect = false;
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  /// Bouton flottant pour IA Photo Fix
  Widget _buildFab(ColorScheme cs) {
    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const IaPhotoFixScreen()),
        );
      },
      icon: const Icon(Icons.auto_fix_high),
      label: const Text('IA Photo Fix'),
    );
  }
}

/// Delegate de recherche semantique
class _SemanticSearchDelegate extends SearchDelegate<String> {
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        onPressed: () => query = '',
        icon: const Icon(Icons.clear),
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, ''),
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text('Recherche semantique: "$query"'),
          const SizedBox(height: 8),
          Text('Analyse IA en cours...',
              style: TextStyle(color: Theme.of(context).colorScheme.primary)),
        ],
      ),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = [
      'Photos de famille', 'Plage au coucher du soleil',
      'Documents avec texte', 'Visages souriants',
      'Photos en exterieur', 'Images en haute resolution',
    ];
    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (_, i) => ListTile(
        leading: const Icon(Icons.auto_awesome),
        title: Text(suggestions[i]),
        onTap: () => query = suggestions[i],
      ),
    );
  }
}

/// Chip de tri IA
class _SortChip {
  final String label;
  final IconData icon;
  const _SortChip(this.label, this.icon);
}

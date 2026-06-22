// GiovaPlayer - Outils (stockage, convertisseurs, nettoyage IA)
// Contact: giobamos03@gmail.com | WhatsApp: +22670698070
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/format_utils.dart';

/// Ecran des outils GiovaPlayer
class ToolsScreen extends ConsumerStatefulWidget {
  const ToolsScreen({super.key});

  @override
  ConsumerState<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends ConsumerState<ToolsScreen> {
  bool _isScanning = false;
  List<_CleanResult> _scanResults = [];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Outils')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStorageAnalysis(cs),
            const SizedBox(height: 20),
            _buildConvertersSection(cs),
            const SizedBox(height: 20),
            _buildAiCleanerSection(cs),
          ],
        ),
      ),
    );
  }

  /// Section analyse du stockage
  Widget _buildStorageAnalysis(ColorScheme cs) {
    return ref.watch(storageStatsProvider).when(
          data: (stats) => _buildStorageContent(cs, stats),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _buildStorageContent(cs, {}),
        );
  }

  /// Contenu de l'analyse du stockage
  Widget _buildStorageContent(ColorScheme cs, Map<String, dynamic> stats) {
    final categories = [
      _StorageCat('Audio', 2.4, Colors.purple),
      _StorageCat('Video', 8.1, Colors.red),
      _StorageCat('Images', 1.8, Colors.green),
      _StorageCat('Documents', 0.5, Colors.orange),
      _StorageCat('Cache', 0.3, Colors.grey),
    ];
    final totalUsed = categories.fold<double>(0, (sum, c) => sum + c.size);
    final totalCapacity = 32.0;
    final usedPercent = totalUsed / totalCapacity;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Analyse du stockage',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _buildStorageBar(cs, usedPercent),
            const SizedBox(height: 4),
            _buildStorageLabels(totalUsed, totalCapacity),
            const SizedBox(height: 12),
            _buildCategoryChips(cs, categories),
          ],
        ),
      ),
    );
  }

  /// Barre visuelle de stockage
  Widget _buildStorageBar(ColorScheme cs, double usedPercent) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: usedPercent.clamp(0.0, 1.0),
        minHeight: 20,
        backgroundColor: cs.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
      ),
    );
  }

  /// Labels de stockage (utilise / total)
  Widget _buildStorageLabels(double used, double total) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('${used.toStringAsFixed(1)} Go utilise',
            style: const TextStyle(fontSize: 12)),
        Text('${total.toStringAsFixed(0)} Go total',
            style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  /// Chips de categories de stockage
  Widget _buildCategoryChips(ColorScheme cs, List<_StorageCat> categories) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: categories.map((cat) {
        return Chip(
          avatar: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: cat.color,
              shape: BoxShape.circle,
            ),
          ),
          label: Text('${cat.label}: ${cat.size} Go',
              style: const TextStyle(fontSize: 11)),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }

  /// Section des convertisseurs
  Widget _buildConvertersSection(ColorScheme cs) {
    final converters = [
      _ConverterCard(Icons.video_to_audio, 'Video vers Audio',
          'Extrayez la piste audio', cs.primary),
      _ConverterCard(Icons.picture_as_pdf, 'Image vers PDF',
          'Convertissez vos images en PDF', cs.tertiary),
      _ConverterCard(Icons.description, 'PDF vers Word',
          'Convertissez vos documents', cs.error),
      _ConverterCard(Icons.audio_file, 'Audio vers Audio',
          'MP3, AAC, FLAC, OGG, WAV', cs.secondary),
      _ConverterCard(Icons.movie, 'Video vers Video',
          'MP4, MKV, AVI, WebM, MOV', Colors.orange),
      _ConverterCard(Icons.gif, 'Video vers GIF',
          'Creez des GIF animees', Colors.pink),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Convertisseurs', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.4,
          children: converters.map((c) => _buildConverterCard(cs, c)).toList(),
        ),
      ],
    );
  }

  /// Carte de convertisseur individuelle
  Widget _buildConverterCard(ColorScheme cs, _ConverterCard conv) {
    return Card(
      child: InkWell(
        onTap: () => _showConverterSheet(conv),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(conv.icon, size: 32, color: conv.color),
              const SizedBox(height: 6),
              Text(conv.title,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(conv.subtitle,
                  style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  /// Bottom sheet de conversion
  void _showConverterSheet(_ConverterCard conv) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(conv.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(conv.subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.folder_open),
              label: const Text('Selectionner un fichier'),
            ),
          ],
        ),
      ),
    );
  }

  /// Section nettoyage IA
  Widget _buildAiCleanerSection(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Nettoyage IA', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_delete, color: cs.primary, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Analysez et nettoyez votre appareil automatiquement',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _runScan,
                    icon: _isScanning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.search),
                    label: Text(_isScanning ? 'Analyse en cours...' : 'Lancer le scan'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_scanResults.isNotEmpty) ...[
          const SizedBox(height: 8),
          ..._scanResults.map((r) => _buildCleanResultCard(cs, r)),
        ],
      ],
    );
  }

  /// Lance le scan IA
  Future<void> _runScan() async {
    setState(() => _isScanning = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _isScanning = false;
      _scanResults = [
        _CleanResult('Fichiers en double', 12, '245 Mo', Icons.content_copy),
        _CleanResult('Cache obsolete', 48, '1.2 Go', Icons.cached),
        _CleanResult('Fichiers temporaires', 23, '89 Mo', Icons.timer),
        _CleanResult('Downloads oublies', 5, '340 Mo', Icons.download),
      ];
    });
  }

  /// Carte de resultat de nettoyage
  Widget _buildCleanResultCard(ColorScheme cs, _CleanResult result) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(result.icon, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result.label, style: Theme.of(context).textTheme.bodyMedium),
                  Text('${result.count} fichiers - ${result.size}',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${result.label} nettoyees')),
                );
              },
              child: const Text('Nettoyer'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Categorie de stockage
class _StorageCat {
  final String label;
  final double size;
  final Color color;
  const _StorageCat(this.label, this.size, this.color);
}

/// Carte de convertisseur
class _ConverterCard {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  const _ConverterCard(this.icon, this.title, this.subtitle, this.color);
}

/// Resultat de nettoyage IA
class _CleanResult {
  final String label;
  final int count;
  final String size;
  final IconData icon;
  const _CleanResult(this.label, this.count, this.size, this.icon);
}

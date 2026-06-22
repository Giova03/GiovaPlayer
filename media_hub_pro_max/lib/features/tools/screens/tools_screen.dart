import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ─── ÉCRAN OUTILS + CONVERTISSEUR + NETTOYEUR ───
/// Features: Convertisseur universel (vidéo→audio, image→PDF, PDF→Word),
/// Nettoyeur IA (doublons, cache, APK inutiles, analyse stockage)
class ToolsScreen extends ConsumerStatefulWidget {
  const ToolsScreen({super.key});

  @override
  ConsumerState<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends ConsumerState<ToolsScreen> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Outils Pro'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          /// ─── ANALYSE STOCKAGE ───
          Text('Stockage', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),

          /// Jauge stockage circulaire
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('89.2 GB utilisés sur 128 GB',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: 0.697,
                                minHeight: 8,
                                backgroundColor: cs.surfaceContainerHighest,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  /// Répartition par catégorie
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StorageChip('Photos', '24 GB', Icons.photo, Colors.green),
                      _StorageChip('Vidéos', '38 GB', Icons.movie, Colors.red),
                      _StorageChip('Audio', '12 GB', Icons.music_note, Colors.blue),
                      _StorageChip('Apps', '8 GB', Icons.apps, Colors.orange),
                      _StorageChip('Autre', '7.2 GB', Icons.folder, Colors.grey),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          /// ─── CONVERTISSEUR UNIVERSEL ───
          Text('Convertisseur', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),

          /// Grille de conversions
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.8,
            children: [
              _ConverterCard(
                icon: Icons.videocam,
                title: 'Vidéo → Audio',
                subtitle: 'MP4/MKV → MP3/FLAC',
                color: cs.primaryContainer,
                onTap: () => _showConverter('video_to_audio'),
              ),
              _ConverterCard(
                icon: Icons.image,
                title: 'Image → PDF',
                subtitle: 'JPG/PNG → PDF multi-pages',
                color: cs.secondaryContainer,
                onTap: () => _showConverter('image_to_pdf'),
              ),
              _ConverterCard(
                icon: Icons.picture_as_pdf,
                title: 'PDF → Word',
                subtitle: 'PDF → DOCX offline',
                color: cs.tertiaryContainer,
                onTap: () => _showConverter('pdf_to_word'),
              ),
              _ConverterCard(
                icon: Icons.audiotrack,
                title: 'Audio → Audio',
                subtitle: 'FLAC/WAV → MP3/AAC/OGG',
                color: cs.errorContainer,
                onTap: () => _showConverter('audio_to_audio'),
              ),
              _ConverterCard(
                icon: Icons.videocam,
                title: 'Vidéo → Vidéo',
                subtitle: 'MKV → MP4, H.264 → H.265',
                color: cs.primaryContainer,
                onTap: () => _showConverter('video_to_video'),
              ),
              _ConverterCard(
                icon: Icons.gif,
                title: 'Vidéo → GIF',
                subtitle: 'Extraire segment → GIF animé',
                color: cs.secondaryContainer,
                onTap: () => _showConverter('video_to_gif'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          /// ─── NETTOYEUR IA ───
          Text('Nettoyeur IA', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),

          /// Scan rapide
          FilledButton.tonalIcon(
            onPressed: _runCleanerScan,
            icon: const Icon(Icons.cleaning_services),
            label: const Text('Lancer le scan IA'),
          ),
          const SizedBox(height: 16),

          /// Résultats du scan
          _CleanerResultCard(
            icon: Icons.content_copy,
            title: 'Fichiers doublons',
            detail: '1.2 GB • 156 doublons trouvés',
            color: Colors.orange,
            onClean: () {},
          ),
          _CleanerResultCard(
            icon: Icons.cached,
            title: 'Cache applicatif',
            detail: '856 MB • 12 apps',
            color: Colors.blue,
            onClean: () {},
          ),
          _CleanerResultCard(
            icon: Icons.android,
            title: 'APK inutiles',
            detail: '340 MB • 7 APK obsolètes',
            color: Colors.green,
            onClean: () {},
          ),
          _CleanerResultCard(
            icon: Icons.download_done,
            title: 'Fichiers temporaires',
            detail: '210 MB • Downloads / TMP',
            color: Colors.purple,
            onClean: () {},
          ),
          _CleanerResultCard(
            icon: Icons.photo_size_select_large,
            title: 'Photos floues',
            detail: '45 MB • 8 photos floues détectées',
            color: Colors.red,
            onClean: () {},
          ),
        ],
      ),
    );
  }

  /// Ouvre le convertisseur pour un type donné
  void _showConverter(String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              switch (type) {
                'video_to_audio' => 'Vidéo → Audio',
                'image_to_pdf' => 'Image → PDF',
                'pdf_to_word' => 'PDF → Word',
                'audio_to_audio' => 'Audio → Audio',
                'video_to_video' => 'Vidéo → Vidéo',
                'video_to_gif' => 'Vidéo → GIF',
                _ => 'Convertisseur',
              },
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            /// Zone de sélection fichier
            Container(
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                  strokeAlign: BorderSide.strokeAlignOutside,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_circle_outline, size: 40),
                    const SizedBox(height: 8),
                    Text('Appuyez pour sélectionner un fichier',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            /// Format de sortie
            Text('Format de sortie', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: switch (type) {
                'video_to_audio' => ['MP3 320k', 'FLAC', 'AAC 256k', 'OPUS 128k', 'WAV']
                    .map((f) => ChoiceChip(label: Text(f), selected: f == 'MP3 320k', onSelectionChanged: (_) {})).toList(),
                'image_to_pdf' => ['A4 Portrait', 'A4 Paysage', 'Letter', 'Personnalisé']
                    .map((f) => ChoiceChip(label: Text(f), selected: f == 'A4 Portrait', onSelectionChanged: (_) {})).toList(),
                'pdf_to_word' => ['DOCX', 'TXT', 'RTF']
                    .map((f) => ChoiceChip(label: Text(f), selected: f == 'DOCX', onSelectionChanged: (_) {})).toList(),
                _ => ['Par défaut']
                    .map((f) => ChoiceChip(label: Text(f), selected: true, onSelectionChanged: (_) {})).toList(),
              },
            ),
            const SizedBox(height: 24),

            /// Bouton convertir
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Conversion démarrée...')),
                  );
                },
                icon: const Icon(Icons.transform),
                label: const Text('Convertir'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Lance le scan du nettoyeur IA
  void _runCleanerScan() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scan IA en cours...')),
    );
  }
}

/// ─── CARTE STOCKAGE ───
class _StorageChip extends StatelessWidget {
  final String label;
  final String size;
  final IconData icon;
  final Color color;

  const _StorageChip(this.label, this.size, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(size, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        Text(label, style: TextStyle(
          fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

/// ─── CARTE CONVERTISSEUR ───
class _ConverterCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ConverterCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              )),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )),
            ],
          ),
        ),
      ),
    );
  }
}

/// ─── CARTE RÉSULTAT NETTOYEUR ───
class _CleanerResultCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final Color color;
  final VoidCallback onClean;

  const _CleanerResultCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.color,
    required this.onClean,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title),
        subtitle: Text(detail, style: const TextStyle(fontSize: 12)),
        trailing: FilledButton.tonal(
          onPressed: onClean,
          child: const Text('Nettoyer'),
        ),
      ),
    );
  }
}

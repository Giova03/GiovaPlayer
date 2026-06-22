// GiovaPlayer - Gestionnaire de telechargements
// Contact: giobamos03@gmail.com | WhatsApp: +22670698070
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/format_utils.dart';

/// Ecran du gestionnaire de telechargements GiovaPlayer
class DownloaderScreen extends ConsumerStatefulWidget {
  const DownloaderScreen({super.key});

  @override
  ConsumerState<DownloaderScreen> createState() => _DownloaderScreenState();
}

class _DownloaderScreenState extends ConsumerState<DownloaderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _urlController = TextEditingController();
  String _detectedPlatform = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _urlController.addListener(_onUrlChanged);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// Detection automatique de la plateforme quand l'URL change
  void _onUrlChanged() {
    final url = _urlController.text;
    if (url.isNotEmpty) {
      setState(() => _detectedPlatform = FormatUtils.detectPlatform(url));
    } else {
      setState(() => _detectedPlatform = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Telechargements'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Nouveau'),
            Tab(text: 'En cours'),
            Tab(text: 'Termines'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNewDownloadTab(cs),
          _buildActiveTab(cs),
          _buildCompletedTab(cs),
        ],
      ),
    );
  }

  /// Onglet nouveau telechargement
  Widget _buildNewDownloadTab(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildUrlInput(cs),
          if (_detectedPlatform.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildPlatformBadge(cs),
          ],
          const SizedBox(height: 16),
          _buildAnalyzeButton(cs),
          const SizedBox(height: 16),
          _buildPlatformQuickLinks(cs),
        ],
      ),
    );
  }

  /// Champ de saisie URL avec auto-analyse
  Widget _buildUrlInput(ColorScheme cs) {
    return TextField(
      controller: _urlController,
      decoration: InputDecoration(
        hintText: 'Collez votre lien ici...',
        prefixIcon: const Icon(Icons.link),
        suffixIcon: _urlController.text.isNotEmpty
            ? IconButton(
                onPressed: () => _urlController.clear(),
                icon: const Icon(Icons.clear),
              )
            : const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onSubmitted: (_) => _analyzeUrl(),
    );
  }

  /// Badge de plateforme detectee
  Widget _buildPlatformBadge(ColorScheme cs) {
    final icon = _getPlatformIcon(_detectedPlatform);
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text('Plateforme: $_detectedPlatform'),
      backgroundColor: cs.primaryContainer,
    );
  }

  /// Bouton d'analyse
  Widget _buildAnalyzeButton(ColorScheme cs) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _analyzeUrl,
        icon: const Icon(Icons.search),
        label: const Text('Analyser le lien'),
      ),
    );
  }

  /// Liens rapides par plateforme
  Widget _buildPlatformQuickLinks(ColorScheme cs) {
    final platforms = [
      _PlatformLink('YouTube', Icons.play_circle_filled, Colors.red),
      _PlatformLink('TikTok', Icons.music_note, Colors.black),
      _PlatformLink('Instagram', Icons.camera_alt, Colors.purple),
      _PlatformLink('Facebook', Icons.thumb_up, Colors.blue),
      _PlatformLink('Twitter/X', Icons.tag, Colors.grey),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Plateformes supportees',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: platforms.map((p) {
            return ActionChip(
              avatar: Icon(p.icon, size: 16, color: p.color),
              label: Text(p.name),
              onPressed: () {
                _urlController.text = 'https://${p.name.toLowerCase()}.com/';
                _onUrlChanged();
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Onglet telechargements en cours
  Widget _buildActiveTab(ColorScheme cs) {
    return ref.watch(activeDownloadsProvider).when(
          data: (downloads) {
            if (downloads.isEmpty) return _buildEmptyState(cs, 'Aucun telechargement en cours');
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: downloads.length,
              itemBuilder: (_, i) => _buildDownloadCard(cs, downloads[i]),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur: $e')),
        );
  }

  /// Carte de telechargement actif
  Widget _buildDownloadCard(ColorScheme cs, Map<String, dynamic> dl) {
    final progress = (dl['progress'] as num?)?.toDouble() ?? 0.0;
    final status = dl['status'] as String? ?? 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_getPlatformIcon(dl['platform'] as String? ?? ''),
                    size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(dl['title'] ?? 'Telechargement',
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  onPressed: () {},
                  icon: Icon(
                    status == 'downloading' ? Icons.pause : Icons.play_arrow,
                    size: 20,
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress / 100),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${progress.toStringAsFixed(1)}%',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                Text(status,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Onglet telechargements termines
  Widget _buildCompletedTab(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.download_done, size: 64, color: cs.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('Aucun telechargement termine',
              style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  /// Etat vide
  Widget _buildEmptyState(ColorScheme cs, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.download, size: 64, color: cs.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  /// Analyse l'URL saisie
  void _analyzeUrl() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    _showFormatSelector();
  }

  /// Bottom sheet de selection du format
  void _showFormatSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Choisir le format',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  _buildFormatOption('Video 1080p', 'MP4 - 1920x1080', Icons.hd),
                  _buildFormatOption('Video 720p', 'MP4 - 1280x720', Icons.hd),
                  _buildFormatOption('Video 480p', 'MP4 - 854x480', Icons.sd),
                  _buildFormatOption('Audio HQ', 'MP3 - 320 kbps', Icons.audiotrack),
                  _buildFormatOption('Audio', 'MP3 - 128 kbps', Icons.audiotrack),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Option de format individuel
  Widget _buildFormatOption(String title, String subtitle, IconData icon) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Telechargement lance: $title')),
        );
      },
    );
  }

  /// Retourne l'icone correspondant a la plateforme
  IconData _getPlatformIcon(String platform) {
    switch (platform) {
      case 'YouTube':
        return Icons.play_circle_filled;
      case 'TikTok':
        return Icons.music_note;
      case 'Instagram':
        return Icons.camera_alt;
      case 'Facebook':
        return Icons.thumb_up;
      case 'Twitter/X':
        return Icons.tag;
      default:
        return Icons.public;
    }
  }
}

/// Lien de plateforme
class _PlatformLink {
  final String name;
  final IconData icon;
  final Color color;
  const _PlatformLink(this.name, this.icon, this.color);
}

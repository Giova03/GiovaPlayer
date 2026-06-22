import 'package:flutter/material.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(appBar: AppBar(title: const Text('Outils Pro')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Stockage
        Text('Stockage', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
          Text('89.2 GB utilises sur 128 GB', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: const LinearProgressIndicator(value: 0.697, minHeight: 8)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _sc('Photos', '24 GB', Icons.photo, Colors.green),
            _sc('Videos', '38 GB', Icons.movie, Colors.red),
            _sc('Audio', '12 GB', Icons.music_note, Colors.blue),
            _sc('Apps', '8 GB', Icons.apps, Colors.orange),
          ]),
        ]))),
        const SizedBox(height: 24),

        // Convertisseur
        Text('Convertisseur', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.8,
          children: [
            _cc(Icons.videocam, 'Video > Audio', 'MP4 > MP3', cs),
            _cc(Icons.image, 'Image > PDF', 'JPG > PDF', cs),
            _cc(Icons.picture_as_pdf, 'PDF > Word', 'PDF > DOCX', cs),
            _cc(Icons.audiotrack, 'Audio > Audio', 'FLAC > MP3', cs),
            _cc(Icons.videocam, 'Video > Video', 'MKV > MP4', cs),
            _cc(Icons.gif, 'Video > GIF', 'Segment > GIF', cs),
          ]),
        const SizedBox(height: 24),

        // Nettoyeur IA
        Text('Nettoyeur IA', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(onPressed: (){}, icon: const Icon(Icons.cleaning_services), label: const Text('Lancer le scan IA')),
        const SizedBox(height: 16),
        ...[(Icons.content_copy,'Doublons','1.2 GB • 156 doublons',Colors.orange),
          (Icons.cached,'Cache','856 MB',Colors.blue),
          (Icons.android,'APK inutiles','340 MB • 7 APK',Colors.green),
          (Icons.photo_size_select_large,'Photos floues','45 MB • 8 photos',Colors.red),
        ].map((c) => Card(margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(leading: Container(width: 36, height: 36,
            decoration: BoxDecoration(color: c.$4.withValues(alpha:0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(c.$1, color: c.$4, size: 20)),
            title: Text(c.$2), subtitle: Text(c.$3, style: const TextStyle(fontSize: 12)),
            trailing: FilledButton.tonal(onPressed: (){}, child: const Text('Nettoyer'))))),

        const SizedBox(height: 24),
        // Securite donnees
        Card(color: cs.tertiaryContainer, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.security, color: cs.onTertiaryContainer), const SizedBox(width: 12),
            Expanded(child: Text('Regles de securite GiovaPlayer', style: TextStyle(color: cs.onTertiaryContainer, fontWeight: FontWeight.w700)))]),
          const SizedBox(height: 12),
          ...['Aucune donnee personnelle collectee','Aucun envoi de donnees a des serveurs',
            'Chiffrement AES-256-GCM pour le coffre-fort','Aucun analytics ou tracking',
            'Permissions demandees uniquement si necessaire','Droit de suppression totale a tout moment',
            'Donnees stockees exclusivement sur appareil local','Anti-screenshot et flou auto pour le coffre',
            'Panic PIN pour suppression immediate','Conformite RGPD par design'].map((r) =>
            Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.check_circle, size: 16, color: cs.onTertiaryContainer),
              const SizedBox(width: 8),
              Expanded(child: Text(r, style: TextStyle(color: cs.onTertiaryContainer, fontSize: 12))),
            ]))),
        ]))),
      ]),
    );
  }

  Widget _sc(String l, String s, IconData i, Color c) => Column(children: [
    Icon(i, color: c, size: 20), const SizedBox(height: 4),
    Text(s, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    Text(l, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
  ]);

  Widget _cc(IconData i, String t, String s, ColorScheme cs) => Card(child: InkWell(onTap: (){},
    borderRadius: BorderRadius.circular(16), child: Padding(padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(i, size: 28, color: cs.primary), const SizedBox(height: 8),
        Text(t, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 2), Text(s, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      ]))));
}

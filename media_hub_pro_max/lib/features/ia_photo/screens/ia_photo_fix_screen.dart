import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../core/utils/file_scanner.dart';

class IaPhotoFixScreen extends ConsumerStatefulWidget {
  const IaPhotoFixScreen({super.key});
  @override
  ConsumerState<IaPhotoFixScreen> createState() => _IaPhotoFixScreenState();
}

class _IaPhotoFixScreenState extends ConsumerState<IaPhotoFixScreen> {
  MediaFile? _selectedImage;
  double _brightness = 0.0;
  double _contrast = 0.0;
  double _saturation = 1.0;
  double _sepia = 0.0;
  bool _proMode = false;
  bool _processing = false;
  String? _savedPath;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final images = ref.watch(imageFilesProvider).valueOrNull ?? [];
    return Scaffold(appBar: AppBar(title: const Text('IA Photo Fix'), actions: [
      if (_selectedImage != null) IconButton(icon: const Icon(Icons.share), onPressed: _shareImage),
    ]), body: Column(children: [
      Expanded(flex: 3, child: Container(color: Colors.black, child: _selectedImage == null
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.add_photo_alternate, size: 64, color: Colors.white54), const SizedBox(height: 12), const Text('Sélectionnez une image', style: TextStyle(color: Colors.white54))]))
        : Stack(children: [
          ColorFiltered(colorFilter: ColorFilter.matrix(_colorMatrix), child: Center(child: Image.file(File(_selectedImage!.path), fit: BoxFit.contain, cacheWidth: 1080, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 64, color: Colors.white54)))),
          if (_processing) const Center(child: CircularProgressIndicator(color: Colors.white)),
        ]))),
      Expanded(flex: 2, child: SingleChildScrollView(child: Column(children: [
        if (_selectedImage == null) SizedBox(height: 80, child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(8),
          itemCount: images.length < 30 ? images.length : 30, itemBuilder: (_, i) => GestureDetector(onTap: () => setState(() => _selectedImage = images[i]),
            child: Container(width: 70, height: 70, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: cs.outline)),
              child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(images[i].path), fit: BoxFit.cover, cacheWidth: 140, errorBuilder: (_, __, ___) => const Icon(Icons.image))))))),
        if (_selectedImage != null) ...[
          Padding(padding: const EdgeInsets.all(8), child: Row(children: [
            Expanded(child: Text(_selectedImage!.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
            TextButton(onPressed: () => setState(() { _selectedImage = null; _savedPath = null; }), child: const Text('Changer')),
          ])),
          SegmentedButton(segments: const [ButtonSegment(value: false, label: Text('Auto')), ButtonSegment(value: true, label: Text('Pro'))],
            selected: {_proMode}, onSelectionChanged: (v) => setState(() => _proMode = v.first)),
          _sl('Luminosité', _brightness, -1, 1, (v) => setState(() => _brightness = v)),
          _sl('Contraste', _contrast, -1, 1, (v) => setState(() => _contrast = v)),
          _sl('Saturation', _saturation, 0, 2, (v) => setState(() => _saturation = v)),
          if (_proMode) _sl('Sepia', _sepia, 0, 1, (v) => setState(() => _sepia = v)),
          if (_savedPath != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [
            Icon(Icons.check_circle, color: cs.primary, size: 16), const SizedBox(width: 8),
            Expanded(child: Text('Sauvegardé: ${p.basename(_savedPath!)}', style: TextStyle(fontSize: 12, color: cs.primary), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ])),
          Padding(padding: const EdgeInsets.all(12), child: Row(children: [
            Expanded(child: FilledButton.icon(onPressed: _processing ? null : _saveImage, icon: _processing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save), label: Text(_processing ? 'Traitement...' : 'Sauvegarder'))),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: _reset, child: const Text('Reset')),
          ])),
        ],
      ]))),
    ]));
  }

  Widget _sl(String l, double v, double mn, double mx, ValueChanged<double> cb) => Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    child: Row(children: [SizedBox(width: 90, child: Text(l, style: const TextStyle(fontSize: 12))), Expanded(child: Slider(value: v, min: mn, max: mx, onChanged: cb))]));

  List<double> get _colorMatrix => [
    (1 + _contrast) * (_saturation + _sepia * 0.3), _sepia * 0.7, _sepia * 0.2, 0, _brightness * 255,
    _sepia * 0.2, (1 + _contrast) * _saturation, _sepia * 0.1, 0, _brightness * 255,
    _sepia * 0.1, _sepia * 0.3, (1 + _contrast) * (_saturation + _sepia * 0.6), 0, _brightness * 255,
    0, 0, 0, 1, 0,
  ];

  Future<void> _saveImage() async {
    if (_selectedImage == null) return;
    setState(() => _processing = true);

    try {
      // Load image
      final originalBytes = await File(_selectedImage!.path).readAsBytes();
      final image = img.decodeImage(originalBytes);
      if (image == null) throw Exception('Image invalide');

      // Apply filters
      var result = image;

      // Brightness
      if (_brightness != 0) {
        result = img.adjustColor(result, brightness: (_brightness * 100).round());
      }

      // Contrast
      if (_contrast != 0) {
        result = img.adjustColor(result, contrast: ((_contrast + 1) * 100).round());
      }

      // Saturation
      if (_saturation != 1.0) {
        result = img.adjustColor(result, saturation: (_saturation * 100).round());
      }

      // Sepia
      if (_sepia > 0) {
        result = img.sepia(result, amount: (_sepia * 100).round());
      }

      // Save to Download directory
      final dir = Directory('/storage/emulated/0/Download/GiovaPlayer');
      if (!dir.existsSync()) dir.createSync(recursive: true);

      final baseName = p.basenameWithoutExtension(_selectedImage!.path);
      final ext = p.extension(_selectedImage!.path).toLowerCase();
      final outputPath = p.join(dir.path, '${baseName}_edited${ext == '.jpg' || ext == '.jpeg' ? '.jpg' : '.png'}');

      final outputBytes = ext == '.jpg' || ext == '.jpeg'
        ? img.encodeJpg(result, quality: 95)
        : img.encodePng(result);

      await File(outputPath).writeAsBytes(outputBytes);

      setState(() { _savedPath = outputPath; _processing = false; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image sauvegardée: ${p.basename(outputPath)}'), action: SnackBarAction(label: 'Ouvrir', onPressed: () => _openFile(outputPath))));
    } catch (e) {
      setState(() => _processing = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    }
  }

  void _openFile(String path) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sauvegardé dans: Download/GiovaPlayer/')));
  }

  void _shareImage() {
    if (_savedPath != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image prête à partager dans Download/GiovaPlayer/')));
    }
  }

  void _reset() => setState(() { _selectedImage = null; _brightness = 0; _contrast = 0; _saturation = 1; _sepia = 0; _savedPath = null; });
}

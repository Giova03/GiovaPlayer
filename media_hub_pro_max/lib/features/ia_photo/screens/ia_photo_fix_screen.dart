import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final images = ref.watch(imageFilesProvider).valueOrNull ?? [];
    return Scaffold(appBar: AppBar(title: const Text('IA Photo Fix')), body: Column(children: [
      Expanded(flex: 3, child: Container(color: Colors.black, child: _selectedImage == null
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.add_photo_alternate, size: 64, color: Colors.white54), const SizedBox(height: 12), const Text('Sélectionnez une image', style: TextStyle(color: Colors.white54))]))
        : ColorFiltered(colorFilter: ColorFilter.matrix(_colorMatrix), child: Center(child: Image.file(File(_selectedImage!.path), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 64, color: Colors.white54)))))),
      Expanded(flex: 2, child: SingleChildScrollView(child: Column(children: [
        if (_selectedImage == null) SizedBox(height: 80, child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(8),
          itemCount: min(images.length, 30), itemBuilder: (_, i) => GestureDetector(onTap: () => setState(() => _selectedImage = images[i]),
            child: Container(width: 70, height: 70, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: cs.outline)),
              child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(images[i].path), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image))))))),
        if (_selectedImage != null) ...[
          Padding(padding: const EdgeInsets.all(8), child: Row(children: [
            Expanded(child: Text(_selectedImage!.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
            TextButton(onPressed: () => setState(() => _selectedImage = null), child: const Text('Changer')),
          ])),
          SegmentedButton(segments: const [ButtonSegment(value: false, label: Text('Auto')), ButtonSegment(value: true, label: Text('Pro'))],
            selected: {_proMode}, onSelectionChanged: (v) => setState(() => _proMode = v.first)),
          _sl('Luminosité', _brightness, -1, 1, (v) => setState(() => _brightness = v)),
          _sl('Contraste', _contrast, -1, 1, (v) => setState(() => _contrast = v)),
          _sl('Saturation', _saturation, 0, 2, (v) => setState(() => _saturation = v)),
          if (_proMode) _sl('Sepia', _sepia, 0, 1, (v) => setState(() => _sepia = v)),
          Padding(padding: const EdgeInsets.all(12), child: Row(children: [
            Expanded(child: FilledButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Filtre appliqué !'))), icon: const Icon(Icons.check), label: const Text('Appliquer'))),
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

  void _reset() => setState(() { _selectedImage = null; _brightness = 0; _contrast = 0; _saturation = 1; _sepia = 0; });
}

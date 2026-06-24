import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

class MediaFile {
  final String path;
  final String name;
  final String extension;
  final int size;
  final DateTime modified;
  final String type;
  String? artist;
  String? album;
  String? title;

  MediaFile({required this.path, required this.name, required this.extension, required this.size, required this.modified, required this.type, this.artist, this.album, this.title});

  String get displayName {
    if (title != null && title!.isNotEmpty) return title!;
    var n = name.replaceAll(RegExp(r'\.\w+$'), '');
    n = n.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
    return n.isEmpty ? name : n;
  }

  String get artistDisplay => (artist != null && artist!.isNotEmpty) ? artist! : 'Artiste inconnu';
  String get folderName => path.substring(path.lastIndexOf('/') + 1, path.lastIndexOf('.'));

  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1048576) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1073741824) return '${(size / 1048576).toStringAsFixed(1)} MB';
    return '${(size / 1073741824).toStringAsFixed(1)} GB';
  }
}

const _audioExts = {'.mp3','.flac','.wav','.aac','.ogg','.m4a','.wma','.opus','.dsf','.dff','.ape','.alac','.aiff','.amr','.mid','.midi','.m4b','.awb','.ac3','.xmf','.rtttl','.rtx','.ota','.imy'};
const _videoExts = {'.mp4','.mkv','.avi','.mov','.wmv','.flv','.webm','.m4v','.3gp','.ts','.mts','.m2ts','.vob','.ogv','.rm','.rmvb','.asf','.divx','.f4v','.svi'};
const _imageExts = {'.jpg','.jpeg','.png','.gif','.bmp','.webp','.tiff','.tif','.svg','.heic','.heif','.raw','.ico','.avif','.pbm','.pgm','.ppm','.tga','.psd'};

class FileScanner {
  final Set<String> _scannedPaths = {};
  List<MediaFile> _audioFiles = [];
  List<MediaFile> _videoFiles = [];
  List<MediaFile> _imageFiles = [];
  bool _hasScanned = false;

  List<MediaFile> get audioFiles => _audioFiles;
  List<MediaFile> get videoFiles => _videoFiles;
  List<MediaFile> get imageFiles => _imageFiles;

  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return true;
    var s = await Permission.manageExternalStorage.status;
    if (s.isGranted) return true;
    s = await Permission.manageExternalStorage.request();
    if (s.isGranted) return true;
    final r = await [Permission.audio, Permission.videos, Permission.photos].request();
    if (r.values.every((p) => p.isGranted)) return true;
    s = await Permission.storage.request();
    if (s.isGranted) return true;
    if (s.isPermanentlyDenied) await openAppSettings();
    return false;
  }

  Future<void> scanAll() async {
    if (_hasScanned) return;
    _scannedPaths.clear(); _audioFiles = []; _videoFiles = []; _imageFiles = [];
    if (!Platform.isAndroid) return;
    try {
      final root = Directory('/storage/emulated/0');
      if (await root.exists()) await _scanDir(root, 10);
    } catch (_) {}
    _audioFiles.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    _videoFiles.sort((a, b) => b.modified.compareTo(a.modified));
    _imageFiles.sort((a, b) => b.modified.compareTo(a.modified));
    _hasScanned = true;
  }

  Future<void> forceRescan() async { _hasScanned = false; await scanAll(); }

  Future<void> _scanDir(Directory dir, int depth) async {
    if (depth <= 0) return;
    try {
      await for (final e in dir.list(followLinks: false)) {
        if (e is File) _processFile(e);
        else if (e is Directory) {
          final n = e.path.substring(e.path.lastIndexOf('/') + 1);
          if (n.startsWith('.') || n == 'cache' || n == 'Cache') continue;
          await _scanDir(e, depth - 1);
        }
      }
    } catch (_) {}
  }

  void _processFile(File file) {
    final path = file.path;
    if (_scannedPaths.contains(path)) return;
    _scannedPaths.add(path);
    final di = path.lastIndexOf('.');
    if (di == -1 || di < path.length - 6) return;
    final ext = path.substring(di).toLowerCase();
    String? type;
    if (_audioExts.contains(ext)) type = 'audio';
    else if (_videoExts.contains(ext)) type = 'video';
    else if (_imageExts.contains(ext)) type = 'image';
    if (type == null) return;
    try {
      final stat = file.statSync();
      final name = path.substring(path.lastIndexOf('/') + 1);
      final mf = MediaFile(path: path, name: name, extension: ext, size: stat.size, modified: stat.modified, type: type);
      if (type == 'audio') { var n = name.replaceAll(ext, ''); if (n.contains(' - ')) { final p = n.split(' - '); mf.artist = p[0].trim(); mf.title = p.sublist(1).join(' - ').trim(); } }
      switch (type) { case 'audio': _audioFiles.add(mf); break; case 'video': _videoFiles.add(mf); break; case 'image': _imageFiles.add(mf); break; }
    } catch (_) {}
  }

  Map<String, List<MediaFile>> getFilesByFolder(String type) {
    final map = <String, List<MediaFile>>{};
    final files = switch (type) { 'audio' => _audioFiles, 'video' => _videoFiles, 'image' => _imageFiles, _ => <MediaFile>[] };
    for (final f in files) { final d = f.path.substring(0, f.path.lastIndexOf('/')); final fn = d.substring(d.lastIndexOf('/') + 1); map.putIfAbsent(fn, () => []).add(f); }
    return map;
  }
}

final fileScannerProvider = Provider<FileScanner>((ref) => FileScanner());
final audioFilesProvider = FutureProvider<List<MediaFile>>((ref) async { final s = ref.watch(fileScannerProvider); await s.requestPermissions(); await s.scanAll(); return s.audioFiles; });
final videoFilesProvider = FutureProvider<List<MediaFile>>((ref) async { final s = ref.watch(fileScannerProvider); await s.requestPermissions(); await s.scanAll(); return s.videoFiles; });
final imageFilesProvider = FutureProvider<List<MediaFile>>((ref) async { final s = ref.watch(fileScannerProvider); await s.requestPermissions(); await s.scanAll(); return s.imageFiles; });

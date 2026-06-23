import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';

final log = Logger();

/// Modèle pour un fichier média scanné
class MediaFile {
  final String path;
  final String name;
  final String extension;
  final int size;
  final DateTime modified;
  final String type; // audio, video, image

  const MediaFile({
    required this.path,
    required this.name,
    required this.extension,
    required this.size,
    required this.modified,
    required this.type,
  });

  String get displayName {
    final n = name.replaceAll(RegExp(r'[_\-]+'), ' ').replaceAll(RegExp(r'\.\w+$'), '').trim();
    return n.isEmpty ? name : n;
  }

  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

// Extensions supportées
const _audioExts = {'.mp3', '.flac', '.wav', '.aac', '.ogg', '.m4a', '.wma', '.opus', '.dsf', '.dff', '.ape', '.alac', '.aiff', '.amr'};
const _videoExts = {'.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v', '.3gp', '.ts', '.mts', '.m2ts'};
const _imageExts = {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.tiff', '.tif', '.svg', '.heic', '.heif', '.raw', '.ico'};

/// Dossiers à scanner sur Android
const _scanDirs = [
  'Music', 'Download', 'DCIM', 'Pictures', 'Movies',
  'Recordings', 'Documents', 'Ringtones', 'Notifications',
  'Alarms', 'Podcasts', 'Audiobooks',
];

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

    // Essayer MANAGE_EXTERNAL_STORAGE d'abord (accès complet)
    var status = await Permission.manageExternalStorage.status;
    if (status.isGranted) return true;

    status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;

    // Fallback : essayer storage permission
    status = await Permission.storage.request();
    if (status.isGranted) return true;

    // Dernier recours : ouvrir les paramètres
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }

    return false;
  }

  Future<void> scanAll() async {
    if (_hasScanned) return; // Éviter de rescanner inutilement

    _scannedPaths.clear();
    _audioFiles = [];
    _videoFiles = [];
    _imageFiles = [];

    if (!Platform.isAndroid && !Platform.isLinux && !Platform.isMacOS && !Platform.isWindows) return;

    try {
      final root = Directory('/storage/emulated/0');
      if (await root.exists()) {
        // Scanner les dossiers connus
        for (final dir in _scanDirs) {
          final d = Directory('${root.path}/$dir');
          if (await d.exists()) {
            await _scanDirectory(d);
          }
        }
        // Scanner la racine (fichiers en vrac)
        try {
          await for (final entity in root.list()) {
            if (entity is File) {
              _processFile(entity);
            }
          }
        } catch (_) {}

        // Scan additionnel dans WhatsApp, Telegram etc.
        for (final extra in [
          'WhatsApp/Media', 'WhatsApp/Media/WhatsApp Video',
          'WhatsApp/Media/WhatsApp Audio', 'WhatsApp/Media/WhatsApp Images',
          'Telegram/Telegram Documents', 'Telegram/Telegram Audio',
          'Android/media', 'Recordings',
        ]) {
          final d = Directory('${root.path}/$extra');
          if (await d.exists()) {
            await _scanDirectory(d, maxDepth: 2);
          }
        }
      }
    } catch (e) {
      log.e('Erreur scan root: $e');
    }

    // Fallback : répertoires de l'app
    try {
      final appDir = await getExternalStorageDirectory();
      if (appDir != null) {
        await _scanDirectory(Directory(appDir.path));
      }
    } catch (_) {}

    // Trier par date
    _audioFiles.sort((a, b) => b.modified.compareTo(a.modified));
    _videoFiles.sort((a, b) => b.modified.compareTo(a.modified));
    _imageFiles.sort((a, b) => b.modified.compareTo(a.modified));

    _hasScanned = true;
    log.i('Scan: ${_audioFiles.length} audio, ${_videoFiles.length} video, ${_imageFiles.length} image');
  }

  /// Forcer un rescan
  Future<void> forceRescan() async {
    _hasScanned = false;
    await scanAll();
  }

  Future<void> _scanDirectory(Directory dir, {int maxDepth = 5, int depth = 0}) async {
    if (depth >= maxDepth) return;
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File) {
          _processFile(entity);
        } else if (entity is Directory && !entity.path.contains('/.')) {
          // Ignorer les dossiers cachés
          await _scanDirectory(entity, maxDepth: maxDepth, depth: depth + 1);
        }
      }
    } catch (_) {
      // Ignorer les erreurs de permission
    }
  }

  void _processFile(File file) {
    final path = file.path;
    if (_scannedPaths.contains(path)) return;
    _scannedPaths.add(path);

    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1) return;
    final ext = path.substring(dotIndex).toLowerCase();

    String? type;
    if (_audioExts.contains(ext)) {
      type = 'audio';
    } else if (_videoExts.contains(ext)) {
      type = 'video';
    } else if (_imageExts.contains(ext)) {
      type = 'image';
    }
    if (type == null) return;

    try {
      final stat = file.statSync();
      final name = path.substring(path.lastIndexOf('/') + 1);
      final media = MediaFile(
        path: path,
        name: name,
        extension: ext,
        size: stat.size,
        modified: stat.modified,
        type: type,
      );
      switch (type) {
        case 'audio': _audioFiles.add(media); break;
        case 'video': _videoFiles.add(media); break;
        case 'image': _imageFiles.add(media); break;
      }
    } catch (_) {}
  }
}

// ─── Providers Riverpod ───

final fileScannerProvider = Provider<FileScanner>((ref) => FileScanner());

final audioFilesProvider = FutureProvider<List<MediaFile>>((ref) async {
  final scanner = ref.watch(fileScannerProvider);
  final hasPerm = await scanner.requestPermissions();
  if (!hasPerm) return [];
  await scanner.scanAll();
  return scanner.audioFiles;
});

final videoFilesProvider = FutureProvider<List<MediaFile>>((ref) async {
  final scanner = ref.watch(fileScannerProvider);
  final hasPerm = await scanner.requestPermissions();
  if (!hasPerm) return [];
  await scanner.scanAll();
  return scanner.videoFiles;
});

final imageFilesProvider = FutureProvider<List<MediaFile>>((ref) async {
  final scanner = ref.watch(fileScannerProvider);
  final hasPerm = await scanner.requestPermissions();
  if (!hasPerm) return [];
  await scanner.scanAll();
  return scanner.imageFiles;
});

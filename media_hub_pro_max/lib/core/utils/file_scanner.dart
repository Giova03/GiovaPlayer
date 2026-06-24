import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';

final log = Logger();

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
  String? genre;
  int? durationMs;

  MediaFile({
    required this.path, required this.name, required this.extension,
    required this.size, required this.modified, required this.type,
    this.artist, this.album, this.title, this.genre, this.durationMs,
  });

  String get displayName {
    if (title != null && title!.isNotEmpty) return title!;
    final n = name.replaceAll(RegExp(r'[_\-]+'), ' ').replaceAll(RegExp(r'\.\w+$'), '').trim();
    return n.isEmpty ? name : n;
  }

  String get artistDisplay => artist ?? 'Artiste inconnu';

  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get durationFormatted {
    if (durationMs == null) return '--:--';
    final d = Duration(milliseconds: durationMs!);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '$h:${m.toString().padLeft(2, "0")}:${s.toString().padLeft(2, "0")}';
    return '$m:${s.toString().padLeft(2, "0")}';
  }
}

const _audioExts = {
  '.mp3', '.flac', '.wav', '.aac', '.ogg', '.m4a', '.wma', '.opus',
  '.dsf', '.dff', '.ape', '.alac', '.aiff', '.amr', '.mid', '.midi',
  '.xmf', '.mxmf', '.rtttl', '.rtx', '.ota', '.imy', '.3gp', '.mp4',
  '.m4b', '.awb', '.ac3', '.dts',
};
const _videoExts = {
  '.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v',
  '.3gp', '.ts', '.mts', '.m2ts', '.vob', '.ogv', '.rm', '.rmvb',
  '.asf', '.divx', '.f4v', '.svi',
};
const _imageExts = {
  '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.tiff', '.tif',
  '.svg', '.heic', '.heif', '.raw', '.ico', '.avif', '.pbm', '.pgm',
  '.ppm', '.tga', '.xcf', '.psd',
};

class FileScanner {
  final Set<String> _scannedPaths = {};
  List<MediaFile> _audioFiles = [];
  List<MediaFile> _videoFiles = [];
  List<MediaFile> _imageFiles = [];
  bool _hasScanned = false;
  int _totalScannedDirs = 0;

  List<MediaFile> get audioFiles => _audioFiles;
  List<MediaFile> get videoFiles => _videoFiles;
  List<MediaFile> get imageFiles => _imageFiles;
  bool get hasScanned => _hasScanned;
  int get totalScannedDirs => _totalScannedDirs;

  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return true;

    // MANAGE_EXTERNAL_STORAGE = accès total
    var status = await Permission.manageExternalStorage.status;
    if (status.isGranted) return true;
    status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;

    // Fallback Android 13+
    final results = await [
      Permission.audio,
      Permission.videos,
      Permission.photos,
    ].request();
    if (results.values.every((s) => s.isGranted)) return true;

    // Fallback storage
    status = await Permission.storage.request();
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
    return false;
  }

  Future<void> scanAll() async {
    if (_hasScanned) return;

    _scannedPaths.clear();
    _audioFiles = [];
    _videoFiles = [];
    _imageFiles = [];
    _totalScannedDirs = 0;

    if (!Platform.isAndroid) return;

    try {
      final root = Directory('/storage/emulated/0');
      if (await root.exists()) {
        // Étape 1: Scanner tous les sous-dossiers de premier niveau
        try {
          await for (final entity in root.list()) {
            if (entity is Directory) {
              // Scanner chaque dossier de premier niveau récursivement
              await _scanDirectory(entity, maxDepth: 8);
            } else if (entity is File) {
              _processFile(entity);
            }
          }
        } catch (e) {
          log.w('Erreur scan racine: $e');
        }

        // Étape 2: Scan profond dans les dossiers connus de médias
        const deepDirs = [
          'Music', 'Download', 'DCIM/Camera', 'DCIM/Screenshots',
          'Pictures/Screenshots', 'Pictures/Instagram', 'Pictures/Facebook',
          'Pictures/WhatsApp', 'Movies', 'Recordings', 'Documents',
          'Ringtones', 'Notifications', 'Alarms', 'Podcasts', 'Audiobooks',
          'WhatsApp/Media/WhatsApp Audio',
          'WhatsApp/Media/WhatsApp Video',
          'WhatsApp/Media/WhatsApp Images',
          'WhatsApp/Media/WhatsApp Animated Gifs',
          'WhatsApp/Media/WhatsApp Documents',
          'Telegram/Telegram Audio',
          'Telegram/Telegram Documents',
          'Telegram/Telegram Images',
          'Telegram/Telegram Video',
          'Telegram/Telegram Music',
          'Android/media/com.whatsapp',
          'Android/media/com.tencent.mm',
          'Android/media/com.instagram.android',
          'Android/media/com.facebook.katana',
          'Android/media/com.google.android.apps.messaging',
          'Android/media/com.Slack',
          'Android/media/com.discord',
          'Android/media/org.telegram.messenger',
          'Android/media/com.zhiliaoapp.musically',
          'Android/media/com.twitter.android',
          'Android/media/com.linkedin.android',
          'Bluetooth',
          'Sounds',
          'Voice Recorder',
          'VoiceRecorder',
          'Call Recordings',
          'Audio',
          'Videos',
          'Photos',
          'Reels',
        ];

        for (final dir in deepDirs) {
          final d = Directory('${root.path}/$dir');
          if (await d.exists()) {
            await _scanDirectory(d, maxDepth: 5);
          }
        }

        // Étape 3: Scanner tous les dossiers Android/media (beaucoup d'apps y stockent des fichiers)
        final androidMedia = Directory('${root.path}/Android/media');
        if (await androidMedia.exists()) {
          try {
            await for (final entity in androidMedia.list()) {
              if (entity is Directory) {
                await _scanDirectory(entity, maxDepth: 4);
              }
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      log.e('Erreur scan principal: $e');
    }

    // Trier par nom pour audio, par date pour vidéo et images
    _audioFiles.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    _videoFiles.sort((a, b) => b.modified.compareTo(a.modified));
    _imageFiles.sort((a, b) => b.modified.compareTo(a.modified));

    _hasScanned = true;
    log.i('Scan terminé: ${_audioFiles.length} audio, ${_videoFiles.length} video, ${_imageFiles.length} image, $_totalScannedDirs dossiers');
  }

  Future<void> forceRescan() async {
    _hasScanned = false;
    await scanAll();
  }

  Future<void> _scanDirectory(Directory dir, {int maxDepth = 8, int depth = 0}) async {
    if (depth >= maxDepth) return;
    _totalScannedDirs++;
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File) {
          _processFile(entity);
        } else if (entity is Directory) {
          final dirName = entity.path.substring(entity.path.lastIndexOf('/') + 1);
          // Ignorer les dossiers cachés et système
          if (dirName.startsWith('.') || dirName == 'cache' || dirName == 'Cache') continue;
          await _scanDirectory(entity, maxDepth: maxDepth, depth: depth + 1);
        }
      }
    } catch (_) {}
  }

  void _processFile(File file) {
    final path = file.path;
    if (_scannedPaths.contains(path)) return;
    _scannedPaths.add(path);

    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex < path.length - 6) return;
    final ext = path.substring(dotIndex).toLowerCase();

    String? type;
    if (_audioExts.contains(ext)) type = 'audio';
    else if (_videoExts.contains(ext)) type = 'video';
    else if (_imageExts.contains(ext)) type = 'image';
    if (type == null) return;

    try {
      final stat = file.statSync();
      final name = path.substring(path.lastIndexOf('/') + 1);
      final mf = MediaFile(
        path: path, name: name, extension: ext,
        size: stat.size, modified: stat.modified, type: type,
      );

      // Extraire artiste/titre du nom de fichier
      if (type == 'audio') {
        _parseAudioName(mf);
      }

      switch (type) {
        case 'audio': _audioFiles.add(mf); break;
        case 'video': _videoFiles.add(mf); break;
        case 'image': _imageFiles.add(mf); break;
      }
    } catch (_) {}
  }

  void _parseAudioName(MediaFile mf) {
    var name = mf.name.replaceAll(mf.extension, '');
    // Essayer "Artiste - Titre"
    if (name.contains(' - ')) {
      final parts = name.split(' - ');
      mf.artist = parts[0].trim();
      mf.title = parts.sublist(1).join(' - ').trim();
    } else if (name.contains('-')) {
      final parts = name.split('-');
      if (parts.length == 2) {
        mf.artist = parts[0].trim();
        mf.title = parts[1].trim();
      }
    }
  }

  /// Obtenir tous les dossiers uniques qui contiennent des fichiers d'un type
  Map<String, List<MediaFile>> getFilesByFolder(String type) {
    final map = <String, List<MediaFile>>{};
    final files = switch (type) {
      'audio' => _audioFiles,
      'video' => _videoFiles,
      'image' => _imageFiles,
      _ => <MediaFile>[],
    };
    for (final f in files) {
      final dir = f.path.substring(0, f.path.lastIndexOf('/'));
      final folderName = dir.substring(dir.lastIndexOf('/') + 1);
      map.putIfAbsent(folderName, () => []).add(f);
    }
    return map;
  }
}

// ─── Providers ───
final fileScannerProvider = Provider<FileScanner>((ref) => FileScanner());

final audioFilesProvider = FutureProvider<List<MediaFile>>((ref) async {
  final scanner = ref.watch(fileScannerProvider);
  await scanner.requestPermissions();
  await scanner.scanAll();
  return scanner.audioFiles;
});

final videoFilesProvider = FutureProvider<List<MediaFile>>((ref) async {
  final scanner = ref.watch(fileScannerProvider);
  await scanner.requestPermissions();
  await scanner.scanAll();
  return scanner.videoFiles;
});

final imageFilesProvider = FutureProvider<List<MediaFile>>((ref) async {
  final scanner = ref.watch(fileScannerProvider);
  await scanner.requestPermissions();
  await scanner.scanAll();
  return scanner.imageFiles;
});

final rescanProvider = StateProvider<int>((ref) => 0);

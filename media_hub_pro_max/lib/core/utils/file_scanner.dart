import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MediaFile {
  final String path;
  final String name;
  final int size;
  final DateTime modified;
  final String? mimeType;
  final Duration? duration;

  const MediaFile({
    required this.path,
    required this.name,
    required this.size,
    required this.modified,
    this.mimeType,
    this.duration,
  });

  String get extension => path.split('.').last.toLowerCase();

  bool get isAudio => ['mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a', 'wma'].contains(extension);
  bool get isVideo => ['mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm'].contains(extension);
  bool get isImage => ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'].contains(extension);

  String get folder => path.substring(0, path.lastIndexOf('/'));

  MediaFile copyWith({
    String? path,
    String? name,
    int? size,
    DateTime? modified,
    String? mimeType,
    Duration? duration,
  }) {
    return MediaFile(
      path: path ?? this.path,
      name: name ?? this.name,
      size: size ?? this.size,
      modified: modified ?? this.modified,
      mimeType: mimeType ?? this.mimeType,
      duration: duration ?? this.duration,
    );
  }
}

class FileScanner {
  Future<List<MediaFile>> scanAudioFiles() async {
    final files = <MediaFile>[];
    final dirs = [
      Directory('/storage/emulated/0/Music'),
      Directory('/storage/emulated/0/Download'),
      Directory('/sdcard/Music'),
    ];
    for (final dir in dirs) {
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File) {
            final name = entity.path.split('/').last;
            final ext = name.split('.').last.toLowerCase();
            if (['mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a', 'wma'].contains(ext)) {
              final stat = await entity.stat();
              files.add(MediaFile(
                path: entity.path,
                name: name,
                size: stat.size,
                modified: stat.modified,
              ));
            }
          }
        }
      }
    }
    return files;
  }

  Future<List<MediaFile>> scanVideoFiles() async {
    final files = <MediaFile>[];
    final dirs = [
      Directory('/storage/emulated/0/Movies'),
      Directory('/storage/emulated/0/Download'),
      Directory('/sdcard/Movies'),
    ];
    for (final dir in dirs) {
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File) {
            final name = entity.path.split('/').last;
            final ext = name.split('.').last.toLowerCase();
            if (['mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm'].contains(ext)) {
              final stat = await entity.stat();
              files.add(MediaFile(
                path: entity.path,
                name: name,
                size: stat.size,
                modified: stat.modified,
              ));
            }
          }
        }
      }
    }
    return files;
  }

  Future<List<MediaFile>> scanImageFiles() async {
    final files = <MediaFile>[];
    final dirs = [
      Directory('/storage/emulated/0/DCIM'),
      Directory('/storage/emulated/0/Pictures'),
      Directory('/sdcard/DCIM'),
    ];
    for (final dir in dirs) {
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File) {
            final name = entity.path.split('/').last;
            final ext = name.split('.').last.toLowerCase();
            if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext)) {
              final stat = await entity.stat();
              files.add(MediaFile(
                path: entity.path,
                name: name,
                size: stat.size,
                modified: stat.modified,
              ));
            }
          }
        }
      }
    }
    return files;
  }

  Future<List<MediaFile>> scanDownloadFiles() async {
    final files = <MediaFile>[];
    final dir = Directory('/storage/emulated/0/Download');
    if (await dir.exists()) {
      await for (final entity in dir.list(recursive: false)) {
        if (entity is File) {
          final stat = await entity.stat();
          files.add(MediaFile(
            path: entity.path,
            name: entity.path.split('/').last,
            size: stat.size,
            modified: stat.modified,
          ));
        }
      }
    }
    return files;
  }
}

final fileScannerProvider = Provider<FileScanner>((ref) => FileScanner());

final audioFilesProvider = FutureProvider<List<MediaFile>>((ref) async {
  final scanner = ref.watch(fileScannerProvider);
  return scanner.scanAudioFiles();
});

final videoFilesProvider = FutureProvider<List<MediaFile>>((ref) async {
  final scanner = ref.watch(fileScannerProvider);
  return scanner.scanVideoFiles();
});

final imageFilesProvider = FutureProvider<List<MediaFile>>((ref) async {
  final scanner = ref.watch(fileScannerProvider);
  return scanner.scanImageFiles();
});

final downloadFilesProvider = FutureProvider<List<MediaFile>>((ref) async {
  final scanner = ref.watch(fileScannerProvider);
  return scanner.scanDownloadFiles();
});

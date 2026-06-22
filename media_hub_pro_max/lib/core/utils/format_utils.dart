// GiovaPlayer - Utilitaires de formatage
// Contact: giobamos03@gmail.com | WhatsApp: +22670698070

/// Utilitaires de formatage pour GiovaPlayer
class FormatUtils {
  FormatUtils._();

  /// Formate une duree en millisecondes vers HH:MM:SS ou MM:SS
  static String formatDuration(int milliseconds) {
    if (milliseconds <= 0) return '0:00';
    final duration = Duration(milliseconds: milliseconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Formate une taille de fichier en octets vers une chaine lisible
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'Ko', 'Mo', 'Go', 'To'];
    int unitIdx = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && unitIdx < units.length - 1) {
      size /= 1024;
      unitIdx++;
    }
    return '${size.toStringAsFixed(unitIdx == 0 ? 0 : 1)} ${units[unitIdx]}';
  }

  /// Formate une vitesse de telechargement (octets/s)
  static String formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond <= 0) return '0 B/s';
    if (bytesPerSecond < 1024) return '$bytesPerSecond B/s';
    if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} Ko/s';
    }
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} Mo/s';
  }

  /// Formate un debit binaire (bits/s)
  static String formatBitrate(int bitsPerSecond) {
    if (bitsPerSecond <= 0) return '0 bps';
    if (bitsPerSecond < 1000) return '$bitsPerSecond bps';
    if (bitsPerSecond < 1000000) {
      return '${(bitsPerSecond / 1000).toStringAsFixed(0)} kbps';
    }
    return '${(bitsPerSecond / 1000000).toStringAsFixed(1)} Mbps';
  }

  /// Formate un taux d'echantillonnage (Hz)
  static String formatSampleRate(int hz) {
    if (hz <= 0) return '0 Hz';
    if (hz < 1000) return '$hz Hz';
    return '${(hz / 1000).toStringAsFixed(1)} kHz';
  }

  /// Extrait l'extension d'un chemin de fichier
  static String getExtension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '';
    return path.substring(dot + 1).toLowerCase();
  }

  /// Verifie si un fichier est un fichier audio
  static bool isAudioFile(String path) {
    const audioExts = {
      'mp3', 'wav', 'flac', 'aac', 'ogg', 'wma', 'm4a',
      'opus', 'aiff', 'alac', 'ape', 'dsd', 'mid', 'midi',
    };
    return audioExts.contains(getExtension(path));
  }

  /// Verifie si un fichier est un fichier video
  static bool isVideoFile(String path) {
    const videoExts = {
      'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm',
      '3gp', 'm4v', 'ts', 'mpg', 'mpeg', 'vob', 'ogv',
    };
    return videoExts.contains(getExtension(path));
  }

  /// Verifie si un fichier est un fichier image
  static bool isImageFile(String path) {
    const imageExts = {
      'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'tiff',
      'tif', 'svg', 'ico', 'heic', 'heif', 'raw', 'cr2',
    };
    return imageExts.contains(getExtension(path));
  }

  /// Detecte la plateforme a partir d'une URL de telechargement
  static String detectPlatform(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      return 'YouTube';
    }
    if (lower.contains('tiktok.com')) return 'TikTok';
    if (lower.contains('instagram.com')) return 'Instagram';
    if (lower.contains('facebook.com') || lower.contains('fb.watch')) {
      return 'Facebook';
    }
    if (lower.contains('twitter.com') || lower.contains('x.com')) {
      return 'Twitter/X';
    }
    return 'Inconnu';
  }
}

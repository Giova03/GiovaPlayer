// GiovaPlayer - Constantes globales de l'application
// Contact: giobamos03@gmail.com | WhatsApp: +22670698070

/// Constantes de l'application GiovaPlayer
class AppConstants {
  AppConstants._();

  /// Nom de l'application
  static const String appName = 'GiovaPlayer';

  /// Version de l'application
  static const String appVersion = '2.0.0';

  /// Email de contact
  static const String contactEmail = 'giobamos03@gmail.com';

  /// WhatsApp de contact
  static const String contactWhatsapp = '+22670698070';

  /// Extensions audio supportees
  static const Set<String> audioExtensions = {
    'mp3', 'wav', 'flac', 'aac', 'ogg', 'wma', 'm4a',
    'opus', 'aiff', 'alac', 'ape', 'dsd', 'mid', 'midi',
  };

  /// Extensions video supportees
  static const Set<String> videoExtensions = {
    'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm',
    '3gp', 'm4v', 'ts', 'mpg', 'mpeg', 'vob', 'ogv',
  };

  /// Extensions image supportees
  static const Set<String> imageExtensions = {
    'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'tiff',
    'tif', 'svg', 'ico', 'heic', 'heif', 'raw', 'cr2',
  };

  /// Code PIN par defaut du coffre-fort
  static const String defaultVaultPin = '1234';

  /// Code PIN de panique (ouvre le coffre leurre)
  static const String panicPin = '9999';

  /// Nombre maximum de tentatives PIN
  static const int maxPinAttempts = 5;

  /// Taille maximale du coffre-fort (octets) - 5 Go
  static const int maxVaultSize = 5 * 1024 * 1024 * 1024;

  /// Nombre maximum de telechargements simultanes
  static const int maxConcurrentDownloads = 3;

  /// Taille du buffer de telechargement (Ko)
  static const int downloadBufferSize = 64;

  /// Nombre de bandes de l'equaliseur
  static const int eqBandCount = 32;

  /// Frequence minimale de l'equaliseur (Hz)
  static const double eqMinFreq = 20.0;

  /// Frequence maximale de l'equaliseur (Hz)
  static const double eqMaxFreq = 20000.0;

  /// Constantes pour la photo IA
  static const String tfliteModelPath = 'assets/models/tflite/photo_enhancer.tflite';

  /// Intensite par defaut de la correction IA
  static const double defaultIaIntensity = 50.0;

  /// Nombre maximum de photos par lot IA
  static const int maxIaBatchSize = 10;

  /// Niveaux de preset IA
  static const Map<String, double> iaPresets = {
    'Subtil': 25.0,
    'Equilibre': 50.0,
    'Standard': 70.0,
    'Intense': 90.0,
  };

  /// Plateformes de telechargement supportees
  static const Map<String, String> downloadPlatforms = {
    'YouTube': 'youtube.com',
    'TikTok': 'tiktok.com',
    'Instagram': 'instagram.com',
    'Facebook': 'facebook.com',
    'Twitter/X': 'twitter.com',
  };

  /// Categories de stockage pour l'analyse
  static const List<String> storageCategories = [
    'Audio', 'Video', 'Images', 'Documents', 'Cache', 'Autres',
  ];

  /// Formats de conversion disponibles
  static const Map<String, List<String>> converterFormats = {
    'video_audio': ['mp3', 'aac', 'flac', 'ogg', 'wav'],
    'image_pdf': ['pdf'],
    'pdf_word': ['docx', 'txt'],
    'audio_audio': ['mp3', 'aac', 'flac', 'ogg', 'wav', 'm4a'],
    'video_video': ['mp4', 'mkv', 'avi', 'webm', 'mov'],
    'video_gif': ['gif'],
  };
}

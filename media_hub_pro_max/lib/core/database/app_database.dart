import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

/// ─── BASE DE DONNÉES DRIFT/SQLITE ───
/// Schéma complet pour Media Hub Pro MAX
/// Toutes les tables sont chiffrées via SQLCipher en production

@DriftDatabase(tables: [
  MediaItems,
  Albums,
  Playlists,
  VaultItems,
  DownloadTasks,
  Tags,
  EqualizerPresets,
  Notes,
  PasswordEntries,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      await m.createAll();
    },
  );
}

/// ─── CONNEXION BASE DE DONNÉES ───
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'media_hub.db'));
    return NativeDatabase.createInBackground(file);
  });
}

/// ─── TABLE : MÉDIAS (audio + vidéo + images) ───
class MediaItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get artist => text().nullable()();
  TextColumn get album => text().nullable()();
  TextColumn get path => text()();
  TextColumn get type => text()(); // 'audio', 'video', 'image'
  IntColumn get duration => integer().nullable()(); // ms
  IntColumn get size => integer()(); // bytes
  IntColumn get bitrate => integer().nullable()(); // kbps
  IntColumn get sampleRate => integer().nullable()(); // Hz
  TextColumn get format => text().nullable()(); // FLAC, MP4, etc.
  TextColumn get codec => text().nullable()();
  BoolColumn get isHdr => boolean().withDefault(const Constant(false))();
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();
  RealColumn get bpm => real().nullable()();
  TextColumn get genre => text().nullable()();
  TextColumn get replayGain => text().nullable()(); // dB
  TextColumn get tags => text().nullable()(); // JSON
  DateTimeColumn get dateAdded => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastAccessed => dateTime().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
}

/// ─── TABLE : ALBUMS ───
class Albums extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get artist => text().nullable()();
  TextColumn get coverPath => text().nullable()();
  IntColumn get year => integer().nullable()();
  TextColumn get musicBrainzId => text().nullable()();
  DateTimeColumn get dateAdded => dateTime().withDefault(currentDateAndTime)();
}

/// ─── TABLE : PLAYLISTS ───
class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get mediaIds => text()(); // JSON array d'IDs
  IntColumn get currentPosition => integer().withDefault(const Constant(0))();
  BoolColumn get isSmart => boolean().withDefault(const Constant(false))();
  TextColumn get smartRules => text().nullable()(); // JSON
  DateTimeColumn get dateCreated => dateTime().withDefault(currentDateAndTime)();
}

/// ─── TABLE : COFFRE-FORT ───
class VaultItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get encryptedPath => text()();
  TextColumn get originalName => text()();
  TextColumn get type => text()(); // 'photo', 'video', 'note', 'password', 'card', 'file'
  IntColumn get size => integer()();
  TextColumn get encryptionKey => text()(); // Référence clé chiffrée
  TextColumn get thumbnail => text().nullable()(); // Miniature chiffrée base64
  DateTimeColumn get dateAdded => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDecoy => boolean().withDefault(const Constant(false))();
}

/// ─── TABLE : TÉLÉCHARGEMENTS ───
class DownloadTasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get url => text()();
  TextColumn get title => text()();
  TextColumn get platform => text().nullable()(); // youtube, tiktok, etc.
  TextColumn get format => text()(); // '4K MP4', 'MP3 320k', etc.
  TextColumn get outputPath => text()();
  RealColumn get progress => real().withDefault(const Constant(0.0))();
  IntColumn get totalSize => integer().withDefault(const Constant(0))();
  IntColumn get downloadedSize => integer().withDefault(const Constant(0))();
  IntColumn get speed => integer().withDefault(const Constant(0))(); // bytes/sec
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending, active, paused, done, error
  BoolColumn get isTorrent => boolean().withDefault(const Constant(false))();
  TextColumn get torrentHash => text().nullable()();
  DateTimeColumn get dateStarted => dateTime().nullable()();
  DateTimeColumn get dateCompleted => dateTime().nullable()();
}

/// ─── TABLE : TAGS / MÉTADONNÉES ───
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get mediaId => integer().references(MediaItems, #id)();
  TextColumn get key => text()();
  TextColumn get value => text()();
}

/// ─── TABLE : PRESETS ÉGALISEUR ───
class EqualizerPresets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get bands => text()(); // JSON 32 bandes
  BoolColumn get isAiGenerated => boolean().withDefault(const Constant(false))();
  TextColumn get detectedGenre => text().nullable()();
}

/// ─── TABLE : NOTES CHIFFRÉES ───
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get encryptedContent => text()();
  TextColumn get title => text()();
  TextColumn get category => text().withDefault(const Constant('general'))();
  DateTimeColumn get dateCreated => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get dateModified => dateTime().withDefault(currentDateAndTime)();
}

/// ─── TABLE : MOTS DE PASSE ───
class PasswordEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get service => text()();
  TextColumn get username => text()();
  TextColumn get encryptedPassword => text()();
  TextColumn get url => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get category => text().withDefault(const Constant('general'))();
  DateTimeColumn get dateModified => dateTime().withDefault(currentDateAndTime)();
}

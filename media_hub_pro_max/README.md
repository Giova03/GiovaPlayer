# 🎬 Media Hub Pro MAX

> **6 apps en 1 APK <90MB, 60fps, 100% offline** sauf download/IA cloud

Flutter 3.24 • Riverpod • Drift/SQLite • FFMPEG • TensorFlow Lite • libsodium

---

## 🚀 30 Fonctionnalités

### 🎵 Audio (7)
1. Lecteur Hi-Res FLAC/WAV/DSF + DAC USB externe
2. Égaliseur 32 bandes + presets IA selon genre détecté
3. Paroles LRC + traduction live + karaoké mode
4. Crossfade intelligent + gapless + ReplayGain auto
5. Détection BPM + mix auto DJ entre 2 morceaux
6. Tag éditeur batch + récupération MusicBrainz
7. Cast Chromecast/AirPlay + double écoute Bluetooth

### 🎬 Vidéo (6)
8. Lecteur 8K HDR10+ Dolby Vision + décodage hardware
9. Sous-titres IA : génération auto + traduction 50 langues
10. Mode VR 360° + gyroscope + split écran casques
11. Découpe vidéo sans perte + fusion + filigrane
12. Extracteur sous-titres + audio + compresseur H.265
13. Mode Kids : verrouillage + lecture éducative

### 🖼️ Galerie + IA Photo (9)
14. Tri IA : visages, objets, OCR, émotion, GPS
15. Recherche sémantique : "photo moi en costume 2022 plage"
16. Éditeur photo IA 1-CLIC : correction auto avec slider intensité
17. Suppression objet + agrandissement IA 4x + restauration
18. Change fond/tenue IA + filtres Stable Diffusion local
19. Collage auto + vidéo souvenir IA avec musique
20. Scan documents + correction perspective + OCR → PDF
21. Doublons + photos floues suggérées suppression
22. Album "Coffre" intégré : chiffrement instantané

### 🔐 Coffre-fort (4)
23. AES-256-GCM + double PIN + empreinte + visage + clé USB OTG
24. Vault decoy + Panic PIN (supprime tout ou ouvre fake)
25. Anti-screenshot + flou auto + photo intrus + GPS
26. Notes chiffrées + mots de passe + scanner carte bancaire

### ⬇️ Downloader + Outils (4)
27. YouTube/TikTok/IG/FB/Twitter 4K/MP3 — analyse auto
28. Torrent + reprise + limite vitesse horaire
29. Convertisseur : vidéo→audio, image→PDF, PDF→Word offline
30. Nettoyeur IA : doublons, cache, APK inutiles + analyse stockage

---

## 📁 Arborescence

```
media_hub_pro_max/
├── lib/
│   ├── main.dart                          # Point d'entrée Riverpod + Material 3
│   ├── core/
│   │   ├── theme/
│   │   │   └── app_theme.dart             # Thème Monet + 20 thèmes custom
│   │   ├── router/
│   │   │   └── app_router.dart            # GoRouter + ShellRoute + NavigationBar
│   │   ├── database/
│   │   │   └── app_database.dart          # Drift/SQLite (9 tables)
│   │   ├── providers/
│   │   │   ├── database_providers.dart    # Providers Drift + stats
│   │   │   └── app_providers.dart         # Permissions + connectivité
│   │   ├── constants/
│   │   │   └── app_constants.dart         # Constantes globales
│   │   └── utils/
│   │       └── format_utils.dart          # Formatage taille/durée/vitesse
│   ├── features/
│   │   ├── audio/
│   │   │   └── screens/
│   │   │       └── audio_player_screen.dart   # Lecteur + EQ + Paroles + Cast
│   │   ├── video/
│   │   │   └── screens/
│   │   │       └── video_player_screen.dart   # 8K HDR + Sous-titres IA + VR + Kids
│   │   ├── gallery/
│   │   │   └── screens/
│   │   │       └── gallery_screen.dart        # Tri IA + Recherche + Sélection
│   │   ├── ia_photo/
│   │   │   ├── screens/
│   │   │   │   └── ia_photo_fix_screen.dart   # Écran IA Photo Fix complet
│   │   │   └── services/
│   │   │       └── ia_photo_fixer.dart        # Pipeline IA TFLite (cœur du module)
│   │   ├── vault/
│   │   │   └── screens/
│   │   │       └── vault_screen.dart          # PIN + Biométrie + Panic + Anti-capture
│   │   ├── downloader/
│   │   │   └── screens/
│   │   │       └── downloader_screen.dart     # URL auto + Torrent + Progress
│   │   └── tools/
│   │       └── screens/
│   │           └── tools_screen.dart          # Convertisseur + Nettoyeur IA
│   └── shared/
│       ├── widgets/
│       ├── extensions/
│       └── providers/
├── assets/
│   ├── models/tflite/                     # Modèles IA (photo_fixer.tflite)
│   ├── models/onnx/                       # Modèles ONNX alternatifs
│   ├── images/
│   ├── rive/                              # Animations Rive
│   ├── fonts/
│   └── lang/                              # Fichiers de traduction
├── test/
│   ├── features/                          # Tests par feature
│   └── core/                              # Tests core
├── android/
├── ios/
├── pubspec.yaml                           # 40+ dépendances
└── README.md
```

---

## 🛠️ Build Étape par Étape

### Prérequis
```bash
# Flutter 3.24+
flutter --version   # Flutter 3.24.x • Dart 3.5.x

# Android Studio / Xcode installés
# NDK 26+ pour FFMPEG + TFLite
# Java 17

# Android SDK : compileSdk 34, minSdk 24, targetSdk 34
# iOS : minimum 15.0
```

### 1. Cloner et installer
```bash
git clone <repo> && cd media_hub_pro_max
flutter pub get
```

### 2. Générer le code Drift
```bash
# Générer les fichiers .g.dart pour la base de données
dart run build_runner build --delete-conflicting-outputs
```

### 3. Placer les modèles IA
```bash
# Télécharger le modèle TFLite pour IA Photo Fix
# et le placer dans :
# assets/models/tflite/photo_fixer.tflite
# assets/models/tflite/face_detection.tflite
# assets/models/tflite/image_segmentation.tflite
```

### 4. Build APK split par architecture (< 90MB)
```bash
# Build par ABI pour réduire la taille
flutter build apk --split-per-abi --release

# Résultat :
# build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk  (~72 MB)
# build/app/outputs/flutter-apk/app-arm64-v8a-release.apk    (~82 MB)
# build/app/outputs/flutter-apk/app-x86_64-release.apk       (~85 MB)
```

### 5. Build iOS
```bash
flutter build ios --release
# Puis ouvrir Runner.xcworkspace dans Xcode
# Archive → Distribute App
```

### 6. Lancer en debug
```bash
flutter run --debug
# Ou sur un device spécifique :
flutter devices
flutter run -d <device_id>
```

### 7. Tests unitaires (objectif 70%)
```bash
flutter test --coverage
# Génère coverage/lcov.info
# Visualiser avec :
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

---

## 🧠 Module IA Photo Fix — Architecture

```
┌─────────────────────────────────────────┐
│          IA Photo Fix Pipeline          │
├─────────────────────────────────────────┤
│                                         │
│  Input : Image sélectionnée             │
│          ↓                              │
│  ┌──────────────────────────────┐       │
│  │ 1. Analyse Histogramme       │       │
│  │    → Expo/Contraste stats    │       │
│  └──────────────┬───────────────┘       │
│                 ↓                       │
│  ┌──────────────────────────────┐       │
│  │ 2. Détection Visages (MLKit) │       │
│  │    → Position + Landmarks    │       │
│  └──────────────┬───────────────┘       │
│                 ↓                       │
│  ┌──────────────────────────────┐       │
│  │ 3. Estimation Bruit          │       │
│  │    → Score 0-1               │       │
│  └──────────────┬───────────────┘       │
│                 ↓                       │
│  ┌──────────────────────────────┐       │
│  │ 4. Correction Auto           │       │
│  │    ├─ Gamma correction       │       │
│  │    ├─ Débruitage bilatéral   │       │
│  │    ├─ Lissage peau visage    │       │
│  │    ├─ Éclaircissement yeux   │       │
│  │    ├─ Netteté adaptative     │       │
│  │    └─ Balance des blancs     │       │
│  └──────────────┬───────────────┘       │
│                 ↓                       │
│  Output : Avant/Après + Slider          │
│                                         │
│  Modèle : TFLite (photo_fixer.tflite)   │
│  100% Offline • < 2s sur Snapdragon 8+  │
└─────────────────────────────────────────┘
```

---

## 🔮 Features V2 + APIs à Brancher

| # | Feature V2 | API / Service | Priorité |
|---|-----------|---------------|----------|
| 1 | **Génération sous-titres Whisper** | OpenAI Whisper API / Whisper.cpp local | Haute |
| 2 | **Suppression objet IA** | LaMa (Large Mask Inpainting) ONNX | Haute |
| 3 | **Agrandissement 4x Real-ESRGAN** | Real-ESRGAN TFLite | Haute |
| 4 | **Change fond IA** | Rembg + segmentation U2Net | Moyenne |
| 5 | **Filtres Stable Diffusion locaux** | Stable Diffusion Lite (ONNX/TFLite) | Moyenne |
| 6 | **Collage auto + vidéo souvenir** | FFmpeg + template engine + musique matching | Moyenne |
| 7 | **Sync cloud chiffré E2E** | API S3-compatible + libsodium sealed boxes | Basse |
| 8 | **Streaming DLNA/UPnP** | DLNA protocol + SSDP discovery | Basse |
| 9 | **Podcast + RSS auto-download** | RSS parser + background download | Basse |
| 10 | **Plugin système** | Dart FFI + plugin marketplace | Future |

---

## 📐 Architecture

```
┌──────────────────────────────────────────────┐
│                   UI Layer                    │
│  Material 3 + Rive Animations + Monet Theme  │
├──────────────────────────────────────────────┤
│               State Management               │
│         Riverpod + BLoC (feature-first)       │
├──────────────────────────────────────────────┤
│                 Domain Layer                  │
│     Models + Use Cases + Business Logic       │
├──────────────────────────────────────────────┤
│                 Data Layer                    │
│  Drift/SQLite + FFMPEG + TFLite + libsodium  │
├──────────────────────────────────────────────┤
│              Platform Layer                   │
│   Android (NDK) + iOS (Metal) + Platform     │
│   Channels (DAC USB, Bluetooth, Gyroscope)   │
└──────────────────────────────────────────────┘
```

---

## ⚡ Performance Targets

| Métrique | Objectif |
|----------|----------|
| Taille APK (split ABI) | < 90 MB |
| FPS animations | 60 fps constant |
| IA Photo Fix | < 2 secondes |
| Démarrage app | < 800ms |
| Scan galerie 1000 photos | < 3 secondes |
| Chiffrement vault 100 photos | < 5 secondes |
| Download 4K YouTube | Vitesse réseau max |
| Mémoire RAM | < 300 MB |

---

## 📝 Conventions Code

- **Langue commentaires** : Français
- **Fonctions** : < 40 lignes
- **Architecture** : Feature-first (audio/, video/, gallery/, etc.)
- **État** : Riverpod pour global, BLoC pour feature-local
- **Chiffrement** : libsodium AES-256-GCM partout
- **Pas de pub, pas de Firebase Analytics**
- **Tests unitaires** : objectif 70% de couverture

---

*Media Hub Pro MAX — Remplacez 6 apps par 1. © 2024*

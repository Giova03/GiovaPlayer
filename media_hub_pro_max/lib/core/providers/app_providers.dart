import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ─── PROVIDERS SERVICES CENTRAUX ───

/// Provider permissions
final permissionStatusProvider = StateNotifierProvider<PermissionNotifier, Map<String, bool>>((ref) {
  return PermissionNotifier();
});

/// Provider connectivité réseau
final isOnlineProvider = StateProvider<bool>((ref) => true);

/// Provider onboarding IA
final onboardingCompleteProvider = StateProvider<bool>((ref) => false);

/// Provider mode Kids
final kidsModeProvider = StateProvider<bool>((ref) => false);

/// Provider thème dynamique
final currentThemeIndexProvider = StateProvider<int>((ref) => 0);

/// ─── NOTIFIER PERMISSIONS ───
class PermissionNotifier extends StateNotifier<Map<String, bool>> {
  PermissionNotifier() : super({
    'storage': false,
    'microphone': false,
    'camera': false,
    'location': false,
    'bluetooth': false,
    'notifications': false,
  });

  /// Demande une permission spécifique
  Future<void> requestPermission(String key) async {
    // En production : permission_handler
    state = {...state, key: true};
  }

  /// Demande toutes les permissions nécessaires
  Future<void> requestAll() async {
    for (final key in state.keys) {
      await requestPermission(key);
    }
  }

  /// Vérifie si toutes les permissions essentielles sont accordées
  bool get hasEssentialPermissions =>
      state['storage'] == true && state['camera'] == true;
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../core/constants/hive_constants.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

class StorageService {
  Box get _settingsBox => Hive.box(HiveConstants.settingsBox);

  bool get isOnboardingComplete =>
      _settingsBox.get(HiveConstants.onboardingComplete, defaultValue: false)
          as bool;

  String? get storageFolderUri =>
      _settingsBox.get(HiveConstants.storageFolderUri) as String?;

  String? get storageFolderPath =>
      _settingsBox.get(HiveConstants.storageFolderPath) as String?;

  String? get selectedModelId =>
      _settingsBox.get(HiveConstants.selectedModelId) as String?;

  Future<void> completeOnboarding({
    required String folderUri,
    required String folderPath,
  }) async {
    await _settingsBox.put(HiveConstants.onboardingComplete, true);
    await _settingsBox.put(HiveConstants.storageFolderUri, folderUri);
    await _settingsBox.put(HiveConstants.storageFolderPath, folderPath);
  }

  Future<void> updateStorageFolder({
    required String folderUri,
    required String folderPath,
  }) async {
    await _settingsBox.put(HiveConstants.storageFolderUri, folderUri);
    await _settingsBox.put(HiveConstants.storageFolderPath, folderPath);
  }

  Future<void> setSelectedModel(String modelId) async {
    await _settingsBox.put(HiveConstants.selectedModelId, modelId);
  }

  Future<void> clearSelectedModel() async {
    await _settingsBox.delete(HiveConstants.selectedModelId);
  }

  Future<void> setSetting(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }

  T getSetting<T>(String key, {required T defaultValue}) {
    return _settingsBox.get(key, defaultValue: defaultValue) as T;
  }
}

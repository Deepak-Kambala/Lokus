import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import '../../domain/entities/ai_model.dart';
import '../datasources/mock_model_data.dart';
import '../../../../core/constants/hive_constants.dart';
import '../../../../services/storage_service.dart';

final modelsRepositoryProvider = Provider<ModelsRepository>((ref) {
  return ModelsRepository(ref.read(storageServiceProvider));
});

class ModelsRepository {
  final StorageService _storageService;

  ModelsRepository(this._storageService);

  Box<AiModel> get _box => Hive.box<AiModel>(HiveConstants.modelsBox);

  List<AiModel> getDownloadedModels() {
    _syncDownloadedFilesFromStorage();
    _repairMissingDownloadedModels();
    return _box.values
        .where((m) =>
            m.status == ModelStatus.downloaded &&
            m.localPath != null &&
            _isUsableGguf(m.localPath!))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<AiModel> getAllLocalModels() {
    return _box.values.toList();
  }

  AiModel? getModelById(String id) {
    _syncDownloadedFilesFromStorage();
    final model = _box.get(id);
    if (model?.status == ModelStatus.downloaded &&
        (model?.localPath == null || !_isUsableGguf(model!.localPath!))) {
      final repaired = model?.copyWith(
        status: ModelStatus.available,
        downloadProgress: 0.0,
        downloadSpeedMbps: 0.0,
        etaSeconds: 0,
        downloadReceivedBytes: 0,
        downloadTotalBytes: 0,
        clearLocalPath: true,
      );
      if (repaired != null) {
        _box.put(id, repaired);
      }
      return repaired;
    }
    return model;
  }

  List<AiModel> getBrowsableModels({String? query, ModelCategory? category}) {
    _syncDownloadedFilesFromStorage();
    var models = MockModelData.getBrowsableModels();

    // Overlay local state (download progress, status) on top of mock data
    for (var i = 0; i < models.length; i++) {
      final local = _box.get(models[i].id);
      if (local != null) {
        models[i] = local;
      }
    }

    models = models
        .where((m) =>
            m.status != ModelStatus.downloaded ||
            m.localPath == null ||
            !_isUsableGguf(m.localPath!))
        .toList();

    if (query != null && query.isNotEmpty) {
      final q = query.toLowerCase();
      models = models
          .where((m) =>
              m.name.toLowerCase().contains(q) ||
              m.provider.toLowerCase().contains(q) ||
              m.tags.any((t) => t.toLowerCase().contains(q)))
          .toList();
    }

    if (category != null) {
      models = models.where((m) => m.category == category).toList();
    }

    return models;
  }

  void _syncDownloadedFilesFromStorage() {
    final root = _storageService.storageFolderPath;
    if (root == null || root.isEmpty) return;

    final modelsDir = Directory(p.join(root, 'models'));
    final rootDir = Directory(root);
    if (!modelsDir.existsSync() && !rootDir.existsSync()) return;

    for (final model in MockModelData.getBrowsableModels()) {
      final local = _box.get(model.id);
      if (local?.status == ModelStatus.downloading ||
          local?.status == ModelStatus.paused) {
        continue;
      }
      if (local?.status == ModelStatus.downloaded &&
          local?.localPath != null &&
          _isUsableGguf(local!.localPath!)) {
        continue;
      }

      final file = _findExistingModelFile(model, rootDir, modelsDir);
      if (file == null) continue;

      _box.put(
        model.id,
        model.copyWith(
          status: ModelStatus.downloaded,
          downloadProgress: 1.0,
          localPath: file.path,
          downloadReceivedBytes: file.lengthSync(),
          downloadTotalBytes: file.lengthSync(),
        ),
      );
    }
  }

  File? _findExistingModelFile(
    AiModel model,
    Directory rootDir,
    Directory modelsDir,
  ) {
    final urlFileName = Uri.tryParse(model.downloadUrl)?.pathSegments.last;
    final candidates = <String>{
      '${model.id}.gguf',
      if (urlFileName != null && urlFileName.toLowerCase().endsWith('.gguf'))
        urlFileName,
    };

    for (final name in candidates) {
      final inModels = File(p.join(modelsDir.path, name));
      if (_isUsableGguf(inModels.path)) return inModels;

      final inRoot = File(p.join(rootDir.path, name));
      if (_isUsableGguf(inRoot.path)) return inRoot;
    }

    return null;
  }

  void _repairMissingDownloadedModels() {
    for (final model in _box.values) {
      if (model.status != ModelStatus.downloaded) continue;
      if (model.localPath != null && _isUsableGguf(model.localPath!)) continue;

      final repaired = model.copyWith(
        status: ModelStatus.available,
        downloadProgress: 0.0,
        downloadSpeedMbps: 0.0,
        etaSeconds: 0,
        downloadReceivedBytes: 0,
        downloadTotalBytes: 0,
        clearLocalPath: true,
      );
      _box.put(model.id, repaired);
    }
  }

  Future<void> saveModel(AiModel model) async {
    await _box.put(model.id, model);
  }

  Future<void> updateModelStatus({
    required String modelId,
    required ModelStatus status,
    double? progress,
    String? localPath,
    double? speedMbps,
    int? etaSeconds,
    int? receivedBytes,
    int? totalBytes,
  }) async {
    final existing = _box.get(modelId);
    if (existing != null) {
      final updated = existing.copyWith(
        status: status,
        downloadProgress: progress,
        localPath: localPath,
        downloadSpeedMbps: speedMbps,
        etaSeconds: etaSeconds,
        downloadReceivedBytes: receivedBytes,
        downloadTotalBytes: totalBytes,
      );
      await _box.put(modelId, updated);
    } else {
      // Find from mock and save
      final mock = MockModelData.getBrowsableModels()
          .where((m) => m.id == modelId)
          .firstOrNull;
      if (mock != null) {
        final updated = mock.copyWith(
          status: status,
          downloadProgress: progress ?? 0.0,
          localPath: localPath,
          downloadSpeedMbps: speedMbps ?? 0.0,
          etaSeconds: etaSeconds,
          downloadReceivedBytes: receivedBytes ?? 0,
          downloadTotalBytes: totalBytes ?? 0,
        );
        await _box.put(modelId, updated);
      }
    }
  }

  Future<void> deleteModel(String modelId) async {
    final model = _box.get(modelId);
    if (model != null) {
      final updated = model.copyWith(
        status: ModelStatus.available,
        downloadProgress: 0.0,
        downloadSpeedMbps: 0.0,
        etaSeconds: 0,
        downloadReceivedBytes: 0,
        downloadTotalBytes: 0,
        clearLocalPath: true,
      );
      await _box.put(modelId, updated);
    }
  }

  bool _isUsableGguf(String path) {
    final file = File(path);
    if (!file.existsSync() || file.lengthSync() < 4) return false;
    final raf = file.openSync();
    try {
      final bytes = raf.readSync(4);
      return bytes.length == 4 &&
          bytes[0] == 0x47 &&
          bytes[1] == 0x47 &&
          bytes[2] == 0x55 &&
          bytes[3] == 0x46;
    } finally {
      raf.closeSync();
    }
  }
}

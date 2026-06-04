import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/models_repository.dart';
import '../domain/entities/ai_model.dart';
import '../../../services/download_service.dart';
import '../../../services/storage_service.dart';

// ── Filters ──────────────────────────────────────────────────────────────────
final selectedCategoryProvider = StateProvider<ModelCategory?>((ref) => null);
final modelSearchQueryProvider  = StateProvider<String>((ref) => '');

// ── Derived lists ─────────────────────────────────────────────────────────────
final modelsRefreshProvider = StateProvider<int>((ref) => 0);
final downloadErrorsProvider = StateProvider<Map<String, String>>((ref) => {});

final browsableModelsProvider = Provider<List<AiModel>>((ref) {
  ref.watch(modelsRefreshProvider);
  final repo     = ref.read(modelsRepositoryProvider);
  final query    = ref.watch(modelSearchQueryProvider);
  final category = ref.watch(selectedCategoryProvider);
  return repo.getBrowsableModels(query: query, category: category);
});

final downloadedModelsProvider = Provider<List<AiModel>>((ref) {
  ref.watch(modelsRefreshProvider);
  return ref.read(modelsRepositoryProvider).getDownloadedModels();
});

// ── Active model ──────────────────────────────────────────────────────────────
final activeModelProvider = StateProvider<AiModel?>((ref) {
  final storageService = ref.read(storageServiceProvider);
  final selectedId = storageService.selectedModelId;
  if (selectedId == null) return null;
  final model = ref.read(modelsRepositoryProvider).getModelById(selectedId);
  if (model?.status != ModelStatus.downloaded || model?.localPath == null) {
    return null;
  }
  return model;
});

// ── Download manager ──────────────────────────────────────────────────────────
class ModelManagerNotifier extends StateNotifier<Map<String, ModelStatus>> {
  final ModelsRepository _repo;
  final DownloadService _dl;
  final Ref _ref;

  ModelManagerNotifier(this._repo, this._dl, this._ref) : super({}) {
    _loadStatuses();
  }

  void _loadStatuses() {
    final map = <String, ModelStatus>{};
    for (final m in _repo.getAllLocalModels()) {
      map[m.id] = m.status;
    }
    state = map;
  }

  Future<void> startDownload(AiModel model) async {
    if (_dl.isDownloading(model.id)) return;

    final errors = Map<String, String>.from(_ref.read(downloadErrorsProvider));
    errors.remove(model.id);
    _ref.read(downloadErrorsProvider.notifier).state = errors;

    await _repo.updateModelStatus(
      modelId: model.id,
      status: ModelStatus.downloading,
      progress: model.downloadProgress.clamp(0.0, 0.999).toDouble(),
    );
    _updateState(model.id, ModelStatus.downloading);

    await _dl.downloadModel(
      model: model,
      onProgress: (prog) async {
        await _repo.updateModelStatus(
          modelId: model.id,
          status: ModelStatus.downloading,
          progress: prog.progress,
          speedMbps: prog.speedMbps,
          etaSeconds: prog.etaSeconds,
        );
        _ref.read(modelsRefreshProvider.notifier).state++;
      },
      onComplete: (localPath) async {
        await _repo.updateModelStatus(
          modelId: model.id,
          status: ModelStatus.downloaded,
          progress: 1.0,
          localPath: localPath,
        );
        _updateState(model.id, ModelStatus.downloaded);
        _ref.read(modelsRefreshProvider.notifier).state++;
      },
      onError: (err) async {
        final shouldResetProgress = err.contains('not a GGUF model') ||
            err.contains('Storage folder not configured') ||
            err.contains('not writable');
        await _repo.updateModelStatus(
          modelId: model.id,
          status: ModelStatus.failed,
          progress: shouldResetProgress ? 0.0 : null,
          speedMbps: 0.0,
          etaSeconds: 0,
        );
        _ref.read(downloadErrorsProvider.notifier).state = {
          ..._ref.read(downloadErrorsProvider),
          model.id: err,
        };
        _updateState(model.id, ModelStatus.failed);
        _ref.read(modelsRefreshProvider.notifier).state++;
      },
    );
  }

  void pauseDownload(String modelId) {
    _dl.pauseDownload(modelId);
    _repo.updateModelStatus(modelId: modelId, status: ModelStatus.paused);
    _updateState(modelId, ModelStatus.paused);
    _ref.read(modelsRefreshProvider.notifier).state++;
  }

  Future<void> resumeDownload(String modelId) async {
    final model = _repo.getModelById(modelId);
    if (model == null) return;
    await startDownload(model);
  }

  void cancelDownload(String modelId) {
    _dl.cancelDownload(modelId);
    _repo.updateModelStatus(
      modelId: modelId, status: ModelStatus.available, progress: 0.0);
    _updateState(modelId, ModelStatus.available);
    _ref.read(modelsRefreshProvider.notifier).state++;
  }

  Future<void> deleteModel(AiModel model) async {
    if (model.localPath != null) {
      await _dl.deleteModelFile(model.localPath!);
    }
    await _repo.deleteModel(model.id);
    final next = Map<String, ModelStatus>.from(state)..remove(model.id);
    state = next;
    _ref.read(modelsRefreshProvider.notifier).state++;
  }

  void _updateState(String modelId, ModelStatus status) {
    state = {...state, modelId: status};
  }
}

final modelManagerProvider =
    StateNotifierProvider<ModelManagerNotifier, Map<String, ModelStatus>>((ref) {
  return ModelManagerNotifier(
    ref.read(modelsRepositoryProvider),
    ref.read(downloadServiceProvider),
    ref,
  );
});

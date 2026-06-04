import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/ai_model.dart';
import '../../data/repositories/models_repository.dart';
import '../../providers/models_provider.dart';
import '../../../../services/storage_service.dart';
import '../../../../shared/theme/app_theme.dart';
import 'model_logo.dart';
import 'package:intl/intl.dart';

class BrowseModelCard extends ConsumerWidget {
  final AiModel model;
  const BrowseModelCard({super.key, required this.model});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(modelManagerProvider);
    final errors = ref.watch(downloadErrorsProvider);
    ref.watch(modelsRefreshProvider);
    final repo = ref.read(modelsRepositoryProvider);

    // Get latest model state
    final latestModel = repo.getModelById(model.id) ?? model;
    final status = statuses[model.id] ?? latestModel.status;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ModelLogo(value: model.providerIcon, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              model.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${model.provider} · ${model.categoryLabel} · ${model.sizeString}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Released ${DateFormat('MMM yyyy').format(model.releaseDate)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textTertiary,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _ActionButton(
                        model: latestModel,
                        status: status,
                      ),
                    ],
                  ),
                  // Download progress bar
                  if (status == ModelStatus.downloading ||
                      status == ModelStatus.paused)
                    _DownloadProgress(model: latestModel),
                  if (status == ModelStatus.failed)
                    _DownloadError(message: errors[model.id]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends ConsumerWidget {
  final AiModel model;
  final ModelStatus status;

  const _ActionButton({required this.model, required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (status) {
      case ModelStatus.downloaded:
        return _buildSelectButton(context, ref);
      case ModelStatus.downloading:
        return _buildPauseButton(ref);
      case ModelStatus.paused:
        return _buildResumeButton(ref);
      case ModelStatus.failed:
        return _buildRetryButton(ref);
      case ModelStatus.available:
        return _buildDownloadButton(ref);
    }
  }

  Widget _buildDownloadButton(WidgetRef ref) {
    return _IconActionBtn(
      icon: Icons.download_rounded,
      color: AppTheme.accent,
      tooltip: 'Download',
      onTap: () => ref.read(modelManagerProvider.notifier).startDownload(model),
    );
  }

  Widget _buildPauseButton(WidgetRef ref) {
    return _IconActionBtn(
      icon: Icons.pause_rounded,
      color: AppTheme.warning,
      tooltip: 'Pause',
      onTap: () =>
          ref.read(modelManagerProvider.notifier).pauseDownload(model.id),
    );
  }

  Widget _buildResumeButton(WidgetRef ref) {
    return _IconActionBtn(
      icon: Icons.play_arrow_rounded,
      color: AppTheme.accent,
      tooltip: 'Resume',
      onTap: () =>
          ref.read(modelManagerProvider.notifier).resumeDownload(model.id),
    );
  }

  Widget _buildRetryButton(WidgetRef ref) {
    return _IconActionBtn(
      icon: Icons.refresh_rounded,
      color: AppTheme.error,
      tooltip: 'Retry',
      onTap: () => ref.read(modelManagerProvider.notifier).startDownload(model),
    );
  }

  Widget _buildSelectButton(BuildContext context, WidgetRef ref) {
    final isActive = ref.watch(activeModelProvider)?.id == model.id;
    return GestureDetector(
      onTap: () {
        ref.read(storageServiceProvider).setSelectedModel(model.id);
        ref.read(activeModelProvider.notifier).state = model;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${model.name} selected'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.accentSurface : AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? AppTheme.accentDim : AppTheme.border,
          ),
        ),
        child: Text(
          isActive ? 'Active' : 'Select',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? AppTheme.accentLight : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _IconActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _IconActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

class _DownloadProgress extends StatelessWidget {
  final AiModel model;
  const _DownloadProgress({required this.model});

  @override
  Widget build(BuildContext context) {
    final pct = (model.downloadProgress * 100).toStringAsFixed(0);
    final speed = model.downloadSpeedMbps > 0
        ? '${model.downloadSpeedMbps.toStringAsFixed(1)} MB/s'
        : '';
    final eta = model.etaSeconds != null && model.etaSeconds! > 0
        ? _formatEta(model.etaSeconds!)
        : '';

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: model.downloadProgress,
              backgroundColor: AppTheme.surfaceHighlight,
              valueColor: AlwaysStoppedAnimation(
                model.status == ModelStatus.paused
                    ? AppTheme.warning
                    : AppTheme.accent,
              ),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Text(
                '$pct%',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              if (speed.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  speed,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
              if (eta.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  eta,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
              if (model.status == ModelStatus.paused) ...[
                const SizedBox(width: 8),
                const Text(
                  'PAUSED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warning,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatEta(int seconds) {
    if (seconds < 60) return '${seconds}s remaining';
    final mins = seconds ~/ 60;
    if (mins < 60) return '${mins}m remaining';
    return '${mins ~/ 60}h ${mins % 60}m remaining';
  }
}

class _DownloadError extends StatelessWidget {
  final String? message;
  const _DownloadError({this.message});

  @override
  Widget build(BuildContext context) {
    final text = message ?? 'Download failed. Tap retry to continue.';
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        text,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          height: 1.35,
          color: AppTheme.error,
        ),
      ),
    );
  }
}

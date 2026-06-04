import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/ai_model.dart';
import '../../data/repositories/models_repository.dart';
import '../../providers/models_provider.dart';
import '../../../../services/storage_service.dart';
import '../../../../shared/theme/app_theme.dart';
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Provider icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Center(
              child: Text(
                model.providerIcon,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
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
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                model.provider,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              _CategoryBadge(label: model.categoryLabel),
                            ],
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
                const SizedBox(height: 6),
                Text(
                  model.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _MetaChip(label: model.sizeString),
                    const SizedBox(width: 6),
                    _MetaChip(label: model.parameterString),
                    const SizedBox(width: 6),
                    _MetaChip(
                      label: DateFormat('MMM yyyy').format(model.releaseDate),
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
      onTap: () => ref.read(modelManagerProvider.notifier).pauseDownload(model.id),
    );
  }

  Widget _buildResumeButton(WidgetRef ref) {
    return _IconActionBtn(
      icon: Icons.play_arrow_rounded,
      color: AppTheme.accent,
      tooltip: 'Resume',
      onTap: () => ref.read(modelManagerProvider.notifier).resumeDownload(model.id),
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
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
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

class _CategoryBadge extends StatelessWidget {
  final String label;
  const _CategoryBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHighlight,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  const _MetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: AppTheme.textSecondary,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

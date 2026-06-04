import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/ai_model.dart';
import '../../providers/models_provider.dart';
import '../../../../services/storage_service.dart';
import '../../../../shared/theme/app_theme.dart';
import 'model_logo.dart';

class DownloadedModelCard extends ConsumerWidget {
  final AiModel model;
  const DownloadedModelCard({super.key, required this.model});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = ref.watch(activeModelProvider)?.id == model.id;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.accentSurface : AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? AppTheme.accentDim : AppTheme.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
                      child: Text(
                        model.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.accentDim,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ACTIVE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accentLight,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                  ],
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
                const SizedBox(height: 8),
                GestureDetector(
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.accentDim
                          : AppTheme.surfaceHighlight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isActive ? AppTheme.accentDim : AppTheme.border,
                      ),
                    ),
                    child: Text(
                      isActive ? 'Selected' : 'Use Model',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? AppTheme.accentLight
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Tooltip(
            message: 'Delete model',
            child: GestureDetector(
              onTap: () => _confirmDelete(context, ref),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceHighlight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  size: 17,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text('Delete Model'),
        content: Text(
          'Remove ${model.name} (${model.sizeString}) from your device?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(modelManagerProvider.notifier).deleteModel(model);
              // Clear active if this was it
              if (ref.read(activeModelProvider)?.id == model.id) {
                ref.read(activeModelProvider.notifier).state = null;
                ref.read(storageServiceProvider).clearSelectedModel();
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/ai_model.dart';
import '../../providers/models_provider.dart';
import '../../../../services/storage_service.dart';
import '../../../../shared/theme/app_theme.dart';

class DownloadedModelCard extends ConsumerWidget {
  final AiModel model;
  const DownloadedModelCard({super.key, required this.model});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = ref.watch(activeModelProvider)?.id == model.id;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.accentSurface : AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? AppTheme.accentDim : AppTheme.border,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceHighlight,
                  borderRadius: BorderRadius.circular(12),
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
                          child: Text(
                            model.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
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
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          model.provider,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          model.categoryLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          model.sizeString,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textTertiary,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
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
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.accentDim
                          : AppTheme.surfaceHighlight,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: isActive
                            ? AppTheme.accentDim
                            : AppTheme.border,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isActive
                              ? Icons.check_rounded
                              : Icons.play_arrow_rounded,
                          size: 14,
                          color: isActive
                              ? AppTheme.accentLight
                              : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isActive ? 'Selected' : 'Use Model',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isActive
                                ? AppTheme.accentLight
                                : AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _confirmDelete(context, ref),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                        color: AppTheme.error.withOpacity(0.2)),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: AppTheme.error,
                  ),
                ),
              ),
            ],
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

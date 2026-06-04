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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _toggleSelection(context, ref, isActive),
      child: Container(
        padding: EdgeInsets.all(14),
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
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          model.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${model.provider} · ${model.categoryLabel} · ${model.sizeString}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: 10),
            Tooltip(
              message: isActive ? 'Selected model' : 'Use model',
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color:
                      isActive ? Color(0xFF143D2A) : AppTheme.surfaceHighlight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive ? Color(0xFF2ED573) : AppTheme.border,
                  ),
                ),
                child: Icon(
                  isActive
                      ? Icons.check_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: isActive ? Color(0xFF2ED573) : AppTheme.textTertiary,
                ),
              ),
            ),
            SizedBox(width: 8),
            Tooltip(
              message: 'Delete model',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _confirmDelete(context, ref),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceHighlight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 17,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleSelection(BuildContext context, WidgetRef ref, bool isActive) {
    if (isActive) {
      ref.read(activeModelProvider.notifier).state = null;
      ref.read(storageServiceProvider).clearSelectedModel();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${model.name} unselected'),
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }

    ref.read(storageServiceProvider).setSelectedModel(model.id);
    ref.read(activeModelProvider.notifier).state = model;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${model.name} selected'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: Text('Delete Model'),
        content: Text(
          'Remove ${model.name} (${model.sizeString}) from your device?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
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
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }
}

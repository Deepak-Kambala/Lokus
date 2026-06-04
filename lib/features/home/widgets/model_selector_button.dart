import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/providers/models_provider.dart';
import '../../../shared/theme/app_theme.dart';

class ModelSelectorButton extends ConsumerWidget {
  const ModelSelectorButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeModel = ref.watch(activeModelProvider);

    return GestureDetector(
      onTap: () => context.push('/models'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (activeModel != null) ...[
              Text(activeModel.providerIcon, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  activeModel.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else ...[
              const Icon(Icons.smart_toy_outlined, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              const Text(
                'Select Model',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
              ),
            ],
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/providers/models_provider.dart';
import '../../models/presentation/widgets/model_logo.dart';
import '../../../shared/theme/app_theme.dart';

class ModelSelectorButton extends ConsumerWidget {
  const ModelSelectorButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeModel = ref.watch(activeModelProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxLabelWidth = (screenWidth - 190).clamp(96.0, 220.0);

    return GestureDetector(
      onTap: () => context.push('/models'),
      child: Tooltip(
        message: activeModel?.name ?? 'Select Model',
        child: Container(
          height: 38,
          padding: EdgeInsets.only(left: 8, right: 10),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (activeModel != null) ...[
                ModelLogo(value: activeModel.providerIcon, size: 24),
                SizedBox(width: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxLabelWidth),
                  child: Text(
                    activeModel.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else ...[
                Icon(
                  Icons.memory_rounded,
                  size: 17,
                  color: AppTheme.textSecondary,
                ),
                SizedBox(width: 8),
                Text(
                  'Select Model',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
              SizedBox(width: 5),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 17,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

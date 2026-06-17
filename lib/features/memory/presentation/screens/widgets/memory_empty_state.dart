import 'package:flutter/material.dart';
import '../../../../../shared/theme/app_theme.dart';

class MemoryEmptyState extends StatelessWidget {
  const MemoryEmptyState({super.key, required this.isTrash});
  final bool isTrash;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Center(
                child: Text(
                  isTrash ? '🗑️' : '🧠',
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isTrash ? 'Trash is Empty' : 'No Memories Yet',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isTrash
                  ? 'Deleted memories will appear here.'
                  : 'Say "Remember that…" during a chat\nor tap + to add one manually.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: AppTheme.textTertiary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

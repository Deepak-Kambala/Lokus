import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/theme/app_theme.dart';
import '../../../domain/entities/memory_model.dart';

class MemoryCard extends ConsumerWidget {
  const MemoryCard({
    super.key,
    required this.memory,
    this.onEdit,
    this.onDelete,
    this.onPin,
    this.onRestore,
    this.isTrash = false,
  });

  final MemoryModel memory;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onPin;
  final VoidCallback? onRestore;
  final bool isTrash;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: memory.isPinned
              ? AppTheme.accent.withValues(alpha: 0.3)
              : AppTheme.border,
          width: memory.isPinned ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isTrash ? null : onEdit,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: category chip + importance + pin + menu
                Row(
                  children: [
                    _CategoryChip(category: memory.category),
                    const SizedBox(width: 8),
                    _ImportanceDot(importance: memory.importance),
                    const Spacer(),
                    if (!isTrash && memory.isPinned)
                      Icon(Icons.push_pin_rounded,
                          size: 14, color: AppTheme.accent),
                    const SizedBox(width: 4),
                    _CardMenu(
                      isTrash: isTrash,
                      isPinned: memory.isPinned,
                      onEdit: onEdit,
                      onDelete: onDelete,
                      onPin: onPin,
                      onRestore: onRestore,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Content
                Text(
                  memory.content,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: isTrash
                        ? AppTheme.textTertiary
                        : AppTheme.textPrimary,
                    height: 1.5,
                    decoration:
                        isTrash ? TextDecoration.lineThrough : null,
                    decorationColor: AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(height: 8),
                // Footer: timestamp
                Text(
                  _formatDate(memory.updatedAt),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─── Category chip ────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});
  final MemoryCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(category.emoji, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Text(
            category.label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _fg,
            ),
          ),
        ],
      ),
    );
  }

  Color get _bg {
    switch (category) {
      case MemoryCategory.preference:
        return const Color(0xFF2D1B2E);
      case MemoryCategory.personalFact:
        return const Color(0xFF1A2A2D);
      case MemoryCategory.project:
        return const Color(0xFF1A2B1A);
      case MemoryCategory.skill:
        return const Color(0xFF2B2A1A);
      case MemoryCategory.custom:
        return const Color(0xFF1E1E26);
    }
  }

  Color get _fg {
    switch (category) {
      case MemoryCategory.preference:
        return const Color(0xFFCF9ECC);
      case MemoryCategory.personalFact:
        return const Color(0xFF9EC9CF);
      case MemoryCategory.project:
        return const Color(0xFF9ECFA0);
      case MemoryCategory.skill:
        return const Color(0xFFCFCA9E);
      case MemoryCategory.custom:
        return const Color(0xFFAEAECC);
    }
  }
}

// ─── Importance dot ───────────────────────────────────────────────────────────

class _ImportanceDot extends StatelessWidget {
  const _ImportanceDot({required this.importance});
  final double importance;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final filled = importance >= _thresholds[i];
          return Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: filled ? _color : AppTheme.border,
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }

  static const _thresholds = [0.2, 0.4, 0.9];

  Color get _color {
    if (importance >= 0.9) return const Color(0xFF9ECFA0);
    if (importance >= 0.4) return const Color(0xFFCFCA9E);
    return const Color(0xFF8E8E93);
  }

  String get _label {
    if (importance >= 0.9) return 'Permanent';
    if (importance >= 0.4) return 'Useful';
    return 'Temporary';
  }
}

// ─── Card context menu ────────────────────────────────────────────────────────

class _CardMenu extends StatelessWidget {
  const _CardMenu({
    required this.isTrash,
    required this.isPinned,
    this.onEdit,
    this.onDelete,
    this.onPin,
    this.onRestore,
  });

  final bool isTrash;
  final bool isPinned;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onPin;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    if (isTrash) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IconBtn(
            icon: Icons.restore_rounded,
            tooltip: 'Restore',
            onTap: () {
              HapticFeedback.lightImpact();
              onRestore?.call();
            },
          ),
          _IconBtn(
            icon: Icons.delete_forever_rounded,
            tooltip: 'Delete permanently',
            color: Colors.redAccent,
            onTap: () {
              HapticFeedback.lightImpact();
              onDelete?.call();
            },
          ),
        ],
      );
    }

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz_rounded,
          size: 16, color: AppTheme.textTertiary),
      color: AppTheme.surfaceElevated,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'edit',
          child: _PopupItem(
              icon: Icons.edit_rounded, label: 'Edit'),
        ),
        PopupMenuItem(
          value: 'pin',
          child: _PopupItem(
            icon: isPinned
                ? Icons.push_pin_outlined
                : Icons.push_pin_rounded,
            label: isPinned ? 'Unpin' : 'Pin',
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: _PopupItem(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: Colors.redAccent,
          ),
        ),
      ],
      onSelected: (v) {
        HapticFeedback.lightImpact();
        switch (v) {
          case 'edit':
            onEdit?.call();
          case 'pin':
            onPin?.call();
          case 'delete':
            onDelete?.call();
        }
      },
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.color,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child:
              Icon(icon, size: 16, color: color ?? AppTheme.textSecondary),
        ),
      ),
    );
  }
}

class _PopupItem extends StatelessWidget {
  const _PopupItem(
      {required this.icon, required this.label, this.color});
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textSecondary;
    return Row(
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: color ?? AppTheme.textPrimary)),
      ],
    );
  }
}

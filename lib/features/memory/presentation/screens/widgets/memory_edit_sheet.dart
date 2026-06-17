import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/theme/app_theme.dart';
import '../../../domain/entities/memory_model.dart';
import '../../providers/memory_provider.dart';

class MemoryEditSheet extends ConsumerStatefulWidget {
  const MemoryEditSheet({super.key, required this.memory});
  final MemoryModel memory;

  @override
  ConsumerState<MemoryEditSheet> createState() => _MemoryEditSheetState();
}

class _MemoryEditSheetState extends ConsumerState<MemoryEditSheet> {
  late final TextEditingController _contentCtrl;
  late MemoryCategory _category;
  late double _importance;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _contentCtrl = TextEditingController(text: widget.memory.content);
    _category = widget.memory.category;
    _importance = widget.memory.importance;
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Edit Memory',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          // Content field
          TextField(
            controller: _contentCtrl,
            maxLines: 4,
            style:
                TextStyle(fontFamily: 'Inter', color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Memory content…',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          // Category picker
          Text('Category',
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          _CategoryPicker(
            selected: _category,
            onChanged: (c) => setState(() => _category = c),
          ),
          const SizedBox(height: 16),
          // Importance slider
          Text('Importance',
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          _ImportanceSlider(
            value: _importance,
            onChanged: (v) => setState(() => _importance = v),
          ),
          const SizedBox(height: 20),
          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.onAccent),
                    )
                  : const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) return;
    setState(() => _saving = true);
    await ref.read(memoryNotifierProvider.notifier).updateMemory(
          memory: widget.memory,
          content: content,
          category: _category,
          importance: _importance,
        );
    if (mounted) Navigator.of(context).pop();
  }
}

// ─── Add Memory Sheet ─────────────────────────────────────────────────────────

class AddMemorySheet extends ConsumerStatefulWidget {
  const AddMemorySheet({super.key});

  @override
  ConsumerState<AddMemorySheet> createState() => _AddMemorySheetState();
}

class _AddMemorySheetState extends ConsumerState<AddMemorySheet> {
  final _contentCtrl = TextEditingController();
  MemoryCategory _category = MemoryCategory.personalFact;
  double _importance = 0.5;
  bool _saving = false;

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text('Add Memory',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              )),
          const SizedBox(height: 16),
          TextField(
            controller: _contentCtrl,
            maxLines: 3,
            autofocus: true,
            style: TextStyle(fontFamily: 'Inter', color: AppTheme.textPrimary),
            decoration: const InputDecoration(hintText: 'What should I remember?'),
          ),
          const SizedBox(height: 16),
          Text('Category',
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          _CategoryPicker(
            selected: _category,
            onChanged: (c) => setState(() => _category = c),
          ),
          const SizedBox(height: 16),
          Text('Importance',
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          _ImportanceSlider(
            value: _importance,
            onChanged: (v) => setState(() => _importance = v),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.onAccent),
                    )
                  : const Text('Save Memory'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) return;
    setState(() => _saving = true);
    await ref.read(memoryNotifierProvider.notifier).saveMemory(
          content: content,
          category: _category,
          importance: _importance,
        );
    if (mounted) Navigator.of(context).pop();
  }
}

// ─── Reusable sub-widgets ─────────────────────────────────────────────────────

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.selected, required this.onChanged});
  final MemoryCategory selected;
  final ValueChanged<MemoryCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: MemoryCategory.values.map((c) {
        final isSelected = c == selected;
        return GestureDetector(
          onTap: () => onChanged(c),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.surfaceHighlight
                  : AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    isSelected ? AppTheme.accent : AppTheme.border,
              ),
            ),
            child: Text(
              c.label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? AppTheme.textPrimary
                    : AppTheme.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ImportanceSlider extends StatelessWidget {
  const _ImportanceSlider(
      {required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = value >= 0.9
        ? 'Permanent (1.0)'
        : value >= 0.4
            ? 'Useful (${value.toStringAsFixed(1)})'
            : 'Temporary (${value.toStringAsFixed(1)})';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: SliderComponentShape.noOverlay,
            activeTrackColor: AppTheme.accent,
            inactiveTrackColor: AppTheme.border,
            thumbColor: AppTheme.accent,
          ),
          child: Slider(
            value: value,
            min: 0.1,
            max: 1.0,
            divisions: 9,
            onChanged: onChanged,
          ),
        ),
        Text(
          label,
          style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: AppTheme.textTertiary),
        ),
      ],
    );
  }
}

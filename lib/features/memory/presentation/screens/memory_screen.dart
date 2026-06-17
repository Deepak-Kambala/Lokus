import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../domain/entities/memory_model.dart';
import '../providers/memory_provider.dart';
import 'widgets/memory_card.dart';
import 'widgets/memory_edit_sheet.dart';
import 'widgets/memory_empty_state.dart';

class MemoryScreen extends ConsumerStatefulWidget {
  const MemoryScreen({super.key});

  @override
  ConsumerState<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends ConsumerState<MemoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  bool _showSearch = false;

  static const _tabs = [
    (label: 'All', icon: Icons.grid_view_rounded),
    (label: 'Preferences', icon: Icons.favorite_rounded),
    (label: 'Projects', icon: Icons.rocket_launch_rounded),
    (label: 'Personal', icon: Icons.person_rounded),
    (label: 'Skills', icon: Icons.bolt_rounded),
    (label: 'Trash', icon: Icons.delete_outline_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(memoryNotifierProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(state),
      body: Column(
        children: [
          // Search bar (animated)
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: _showSearch ? _buildSearchBar(state) : const SizedBox.shrink(),
          ),
          // Tab bar
          _buildTabBar(),
          const SizedBox(height: 4),
          // Body
          Expanded(
            child: state.isLoading
                ? _buildLoadingState()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _MemoryTabBody(memories: state.displayList),
                      _MemoryTabBody(memories: state.preferences),
                      _MemoryTabBody(memories: state.projects),
                      _MemoryTabBody(memories: state.personalFacts),
                      _MemoryTabBody(memories: state.skills),
                      _TrashTabBody(memories: state.deletedMemories),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: _buildFab(context),
    );
  }

  PreferredSizeWidget _buildAppBar(MemoryState state) {
    return AppBar(
      backgroundColor: AppTheme.background,
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            color: AppTheme.textSecondary, size: 18),
      ),
      title: Column(
        children: [
          Text(
            'Memory',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            '${state.allMemories.length} stored',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Search memories',
          onPressed: () {
            setState(() => _showSearch = !_showSearch);
            if (!_showSearch) {
              _searchController.clear();
              ref.read(memoryNotifierProvider.notifier).search('');
            }
          },
          icon: Icon(
            _showSearch ? Icons.search_off_rounded : Icons.search_rounded,
            color: AppTheme.textSecondary,
            size: 20,
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildSearchBar(MemoryState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search memories…',
          prefixIcon:
              Icon(Icons.search_rounded, color: AppTheme.textTertiary, size: 18),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded,
                      color: AppTheme.textTertiary, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(memoryNotifierProvider.notifier).search('');
                  },
                )
              : null,
        ),
        onChanged: (v) {
          ref.read(memoryNotifierProvider.notifier).search(v);
          setState(() {}); // rebuild for suffix icon
        },
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: const EdgeInsets.all(4),
        indicator: BoxDecoration(
          color: AppTheme.surfaceHighlight,
          borderRadius: BorderRadius.circular(8),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AppTheme.textPrimary,
        unselectedLabelColor: AppTheme.textTertiary,
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        tabs: _tabs
            .map((t) => Tab(
                  height: 36,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(t.icon, size: 14),
                      const SizedBox(width: 5),
                      Text(t.label),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(height: 12),
          Text('Loading memories…',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
    return FloatingActionButton.extended(
      backgroundColor: AppTheme.accent,
      foregroundColor: AppTheme.onAccent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onPressed: () => _showAddMemorySheet(context),
      icon: const Icon(Icons.add_rounded, size: 18),
      label: const Text(
        'Add Memory',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _showAddMemorySheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddMemorySheet(),
    );
  }
}

// ─── Tab body (active memories) ───────────────────────────────────────────────

class _MemoryTabBody extends ConsumerWidget {
  const _MemoryTabBody({required this.memories});

  final List<MemoryModel> memories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (memories.isEmpty) {
      return const MemoryEmptyState(isTrash: false);
    }

    // Pinned first
    final pinned = memories.where((m) => m.isPinned).toList();
    final unpinned = memories.where((m) => !m.isPinned).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        if (pinned.isNotEmpty) ...[
          _SectionHeader(label: 'Pinned', icon: Icons.push_pin_rounded),
          ...pinned.map((m) => _buildCard(context, ref, m)),
          const SizedBox(height: 8),
        ],
        if (unpinned.isNotEmpty) ...[
          if (pinned.isNotEmpty)
            _SectionHeader(label: 'All', icon: Icons.list_rounded),
          ...unpinned.map((m) => _buildCard(context, ref, m)),
        ],
      ],
    );
  }

  Widget _buildCard(
      BuildContext context, WidgetRef ref, MemoryModel memory) {
    return MemoryCard(
      key: ValueKey(memory.id),
      memory: memory,
      onEdit: () => _showEditSheet(context, ref, memory),
      onDelete: () => _confirmDelete(context, ref, memory),
      onPin: () => ref.read(memoryNotifierProvider.notifier).togglePin(memory.id),
    );
  }

  Future<void> _showEditSheet(
      BuildContext context, WidgetRef ref, MemoryModel memory) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MemoryEditSheet(memory: memory),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, MemoryModel memory) async {
    HapticFeedback.lightImpact();
    ref.read(memoryNotifierProvider.notifier).softDeleteMemory(memory.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Memory moved to Trash'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () =>
                ref.read(memoryNotifierProvider.notifier).restoreMemory(memory.id),
          ),
        ),
      );
    }
  }
}

// ─── Trash tab ────────────────────────────────────────────────────────────────

class _TrashTabBody extends ConsumerWidget {
  const _TrashTabBody({required this.memories});

  final List<MemoryModel> memories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (memories.isEmpty) {
      return const MemoryEmptyState(isTrash: true);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Items in trash can be permanently removed.',
                  style: TextStyle(
                      color: AppTheme.textTertiary, fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: () => _confirmPurge(context, ref),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  padding: EdgeInsets.zero,
                ),
                child: const Text('Empty Trash',
                    style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            itemCount: memories.length,
            itemBuilder: (_, i) {
              final m = memories[i];
              return MemoryCard(
                key: ValueKey(m.id),
                memory: m,
                isTrash: true,
                onRestore: () =>
                    ref.read(memoryNotifierProvider.notifier).restoreMemory(m.id),
                onDelete: () => ref
                    .read(memoryNotifierProvider.notifier)
                    .deleteMemory(m.id),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _confirmPurge(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: Text('Empty Trash',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
        content: Text(
          'This will permanently delete all trashed memories. This cannot be undone.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (ok == true) {
      ref.read(memoryNotifierProvider.notifier).purgeDeletedMemories();
    }
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 13, color: AppTheme.textTertiary),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.textTertiary,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

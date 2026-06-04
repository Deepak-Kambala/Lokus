import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../domain/entities/ai_model.dart';
import '../../providers/models_provider.dart';
import '../../../../services/storage_service.dart';
import '../widgets/browse_model_card.dart';
import '../widgets/downloaded_model_card.dart';

class ModelManagerScreen extends ConsumerStatefulWidget {
  const ModelManagerScreen({super.key});

  @override
  ConsumerState<ModelManagerScreen> createState() => _ModelManagerScreenState();
}

class _ModelManagerScreenState extends ConsumerState<ModelManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Models'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Downloaded'),
            Tab(text: 'Browse Models'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DownloadedTab(),
          _BrowseTab(),
        ],
      ),
    );
  }
}

// ── Downloaded Tab ────────────────────────────────────────────────────────────

class _DownloadedTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloaded = ref.watch(downloadedModelsProvider);
    final storageService = ref.read(storageServiceProvider);
    final folderPath = storageService.storageFolderPath ?? 'Not set';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StorageCard(folderPath: folderPath),
        const SizedBox(height: 20),
        if (downloaded.isEmpty)
          _EmptyDownloaded()
        else ...[
          const Text(
            'ON DEVICE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.textTertiary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          ...downloaded.map(
            (model) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DownloadedModelCard(model: model),
            ),
          ),
        ],
      ],
    );
  }
}

class _StorageCard extends ConsumerWidget {
  final String folderPath;
  const _StorageCard({required this.folderPath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayPath = folderPath.length > 38
        ? '...${folderPath.substring(folderPath.length - 38)}'
        : folderPath;

    // Get actual disk stats if possible
    double usedGb = 0;
    double totalGb = 64;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_rounded,
                  size: 16, color: AppTheme.accent),
              const SizedBox(width: 8),
              const Text(
                'Custom folder',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => context.push('/settings'),
                child: const Text(
                  'Change Folder',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            displayPath,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textPrimary,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: usedGb / totalGb,
                        backgroundColor: AppTheme.surfaceHighlight,
                        valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${usedGb.toStringAsFixed(1)} GB used · ${(totalGb - usedGb).toStringAsFixed(1)} GB free',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyDownloaded extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Icon(Icons.download_outlined,
                  size: 26, color: AppTheme.textTertiary),
            ),
            const SizedBox(height: 16),
            const Text(
              'No models downloaded',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Browse models to download one',
              style: TextStyle(fontSize: 13, color: AppTheme.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Browse Tab ────────────────────────────────────────────────────────────────

class _BrowseTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final models = ref.watch(browsableModelsProvider);

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: _SearchField(),
        ),
        // Category chips
        SizedBox(
          height: 38,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            children: [
              _CategoryChip(label: 'All', value: null),
              ...ModelCategory.values.map(
                (cat) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _CategoryChip(
                    label: _categoryLabel(cat),
                    value: cat,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: models.length,
            separatorBuilder: (_, __) =>
                Container(height: 1, color: AppTheme.borderSubtle),
            itemBuilder: (context, index) =>
                BrowseModelCard(model: models[index]),
          ),
        ),
      ],
    );
  }

  String _categoryLabel(ModelCategory cat) {
    switch (cat) {
      case ModelCategory.general:
        return 'General';
      case ModelCategory.coding:
        return 'Coding';
      case ModelCategory.reasoning:
        return 'Reasoning';
      case ModelCategory.multimodal:
        return 'Multimodal';
      case ModelCategory.instruct:
        return 'Instruct';
      case ModelCategory.chat:
        return 'Chat';
    }
  }
}

class _SearchField extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      onChanged: (v) =>
          ref.read(modelSearchQueryProvider.notifier).state = v,
      style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search models...',
        prefixIcon: const Icon(Icons.search_rounded, size: 18),
        suffixIcon: _ctrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                onPressed: () {
                  _ctrl.clear();
                  ref.read(modelSearchQueryProvider.notifier).state = '';
                },
              )
            : null,
        filled: true,
        fillColor: AppTheme.surface,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.accent),
        ),
      ),
    );
  }
}

class _CategoryChip extends ConsumerWidget {
  final String label;
  final ModelCategory? value;

  const _CategoryChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCategoryProvider) == value;

    return GestureDetector(
      onTap: () =>
          ref.read(selectedCategoryProvider.notifier).state = value,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accentSurface : AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppTheme.accentDim : AppTheme.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? AppTheme.accentLight : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

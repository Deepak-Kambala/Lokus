import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../domain/entities/ai_model.dart';
import '../../data/repositories/models_repository.dart';
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
          icon: Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text('Models'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
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
      padding: EdgeInsets.all(16),
      children: [
        _StorageCard(folderPath: folderPath),
        SizedBox(height: 20),
        if (downloaded.isEmpty)
          _EmptyDownloaded()
        else ...[
          Text(
            'ON DEVICE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.textTertiary,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 10),
          ...downloaded.map(
            (model) => Padding(
              padding: EdgeInsets.only(bottom: 10),
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

    return GestureDetector(
      onTap: () => _showFolderSheet(context),
      child: Container(
        padding: EdgeInsets.all(16),
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
                Icon(Icons.folder_rounded, size: 16, color: AppTheme.accent),
                SizedBox(width: 8),
                Text(
                  'Custom folder',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
                Spacer(),
                Row(
                  children: [
                    Text(
                      'Manage',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded,
                        size: 15, color: AppTheme.accent),
                  ],
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              displayPath,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textPrimary,
                fontFamily: 'monospace',
              ),
            ),
            SizedBox(height: 12),
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
                          valueColor: AlwaysStoppedAnimation(AppTheme.accent),
                          minHeight: 4,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '${usedGb.toStringAsFixed(1)} GB used · ${(totalGb - usedGb).toStringAsFixed(1)} GB free',
                        style: TextStyle(
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
      ),
    );
  }

  void _showFolderSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => const _ModelFolderSheet(),
    );
  }
}

class _ModelFolderSheet extends ConsumerWidget {
  const _ModelFolderSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path =
        ref.read(storageServiceProvider).storageFolderPath ?? 'Not set';
    final displayPath =
        path.length > 48 ? '...${path.substring(path.length - 48)}' : path;

    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'Manage Storage Folder',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            displayPath,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontFamily: 'monospace',
            ),
          ),
          SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _chooseFolder(context, ref),
              icon: Icon(Icons.folder_open_rounded, size: 16),
              label: Text('Choose Folder'),
            ),
          ),
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _createFolder(context, ref),
              icon: Icon(Icons.create_new_folder_outlined, size: 16),
              label: Text('Create Folder'),
            ),
          ),
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _useAppStorage(context, ref),
              icon: Icon(Icons.phone_android_rounded, size: 16),
              label: Text('Use App Storage'),
            ),
          ),
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Future<void> _chooseFolder(BuildContext context, WidgetRef ref) async {
    try {
      final hasPermission = await _ensureExternalStoragePermission(context);
      if (!hasPermission) return;

      final path = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose Lokus storage folder',
      );
      if (path == null) return;
      await _applyFolder(context, ref, path);
    } catch (e) {
      _showError(context, e);
    }
  }

  Future<void> _createFolder(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: 'Lokus');
    final folderName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: Text('Create Folder'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Folder name',
            hintText: 'Lokus',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (folderName == null || folderName.isEmpty || !context.mounted) return;

    try {
      final hasPermission = await _ensureExternalStoragePermission(context);
      if (!hasPermission) return;
      final parent = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose parent location',
      );
      if (parent == null) return;
      final path = '${parent.replaceFirst(RegExp(r'/$'), '')}/$folderName';
      await _applyFolder(context, ref, path);
    } catch (e) {
      _showError(context, e);
    }
  }

  Future<void> _useAppStorage(BuildContext context, WidgetRef ref) async {
    try {
      final baseDir = Platform.isAndroid
          ? await getExternalStorageDirectory()
          : await getApplicationDocumentsDirectory();
      if (baseDir == null) {
        throw FileSystemException('Device storage is not available.');
      }
      await _applyFolder(context, ref, '${baseDir.path}/Lokus');
    } catch (e) {
      _showError(context, e);
    }
  }

  Future<void> _applyFolder(
    BuildContext context,
    WidgetRef ref,
    String path,
  ) async {
    await _ensureWritableFolder(path);
    await _resetModelsAfterStorageChange(ref);
    await ref.read(storageServiceProvider).updateStorageFolder(
          folderUri: path,
          folderPath: path,
        );
    if (!context.mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Storage folder updated')),
    );
  }

  Future<void> _ensureWritableFolder(String path) async {
    final dir = Directory(path);
    await dir.create(recursive: true);
    await Directory('${dir.path}/models').create(recursive: true);
    await Directory('${dir.path}/chats').create(recursive: true);
    final probe = File('${dir.path}/.lokus_write_test');
    await probe.writeAsString('ok', flush: true);
    if (await probe.exists()) await probe.delete();
  }

  Future<bool> _ensureExternalStoragePermission(BuildContext context) async {
    if (!Platform.isAndroid) return true;
    if (await Permission.manageExternalStorage.isGranted) return true;
    final status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Storage access is required.')),
    );
    return false;
  }

  Future<void> _resetModelsAfterStorageChange(WidgetRef ref) async {
    final repo = ref.read(modelsRepositoryProvider);
    final downloaded = ref.read(downloadedModelsProvider);
    for (final model in downloaded) {
      await repo.deleteModel(model.id);
    }
    await ref.read(storageServiceProvider).clearSelectedModel();
    ref.read(activeModelProvider.notifier).state = null;
    ref.read(modelsRefreshProvider.notifier).state++;
  }

  void _showError(BuildContext context, Object error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Storage folder is not writable: $error')),
    );
  }
}

class _EmptyDownloaded extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: 60),
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
              child: Icon(Icons.download_outlined,
                  size: 26, color: AppTheme.textTertiary),
            ),
            SizedBox(height: 16),
            Text(
              'No models downloaded',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            SizedBox(height: 6),
            Text(
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
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: _SearchField(),
        ),
        // Category chips
        SizedBox(
          height: 38,
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            children: [
              _CategoryChip(label: 'All', value: null),
              ...ModelCategory.values.map(
                (cat) => Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: _CategoryChip(
                    label: _categoryLabel(cat),
                    value: cat,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      onChanged: (v) => ref.read(modelSearchQueryProvider.notifier).state = v,
      cursorColor: AppTheme.accent,
      style: TextStyle(fontSize: 14, color: AppTheme.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search models...',
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 18,
          color: AppTheme.textSecondary,
        ),
        suffixIcon: _ctrl.text.isNotEmpty
            ? IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
                onPressed: () {
                  _ctrl.clear();
                  ref.read(modelSearchQueryProvider.notifier).state = '';
                },
              )
            : null,
        filled: true,
        fillColor: AppTheme.surface,
        contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.accent),
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
      onTap: () => ref.read(selectedCategoryProvider.notifier).state = value,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../conversations/providers/conversations_provider.dart';
import '../../../../services/storage_service.dart';
import '../../../../shared/theme/app_theme.dart';

final _selectedPathProvider = StateProvider<String?>((ref) => null);
final _selectedUriProvider = StateProvider<String?>((ref) => null);
final _isLoadingProvider = StateProvider<bool>((ref) => false);

class StorageSetupScreen extends ConsumerWidget {
  const StorageSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPath = ref.watch(_selectedPathProvider);
    final isLoading = ref.watch(_isLoadingProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 52),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppTheme.accentSurface,
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: AppTheme.accentDim, width: 1),
                        ),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: AppTheme.accent,
                          size: 28,
                        ),
                      ),
                      SizedBox(height: 28),
                      Text(
                        'Select Storage\nLocation',
                        style: Theme.of(context)
                            .textTheme
                            .displayLarge
                            ?.copyWith(height: 1.15),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Choose where AI models and app data will be stored on your device.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                      SizedBox(height: 32),
                      _StorageInfoRow(),
                      SizedBox(height: 28),
                      if (selectedPath != null)
                        _SelectedFolderCard(path: selectedPath)
                      else
                        _EmptyFolderCard(),
                      SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _FolderButton(
                              icon: Icons.folder_open_rounded,
                              label: 'Choose Folder',
                              onTap: () => _pickFolder(context, ref),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _FolderButton(
                              icon: Icons.create_new_folder_outlined,
                              label: 'Create Folder',
                              onTap: () => _createNewFolder(context, ref),
                            ),
                          ),
                        ],
                      ),
                      Spacer(),
                      SizedBox(height: 34),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: selectedPath != null && !isLoading
                              ? () => _continue(context, ref)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            disabledBackgroundColor: AppTheme.surfaceHighlight,
                            disabledForegroundColor: AppTheme.textTertiary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : Text(
                                  'Continue',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _pickFolder(BuildContext context, WidgetRef ref) async {
    try {
      final hasPermission = await _ensureExternalStoragePermission(
        context,
        ref,
      );
      if (!hasPermission) return;

      final path = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose Lokus storage folder',
      );
      if (path == null) return;

      await _ensureWritableFolder(path);
      ref.read(_selectedPathProvider.notifier).state = path;
      ref.read(_selectedUriProvider.notifier).state = path;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick folder: $e')),
        );
      }
    }
  }

  Future<void> _createNewFolder(BuildContext context, WidgetRef ref) async {
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
    if (folderName == null || folderName.isEmpty) return;
    if (!context.mounted) return;

    try {
      final hasPermission = await _ensureExternalStoragePermission(
        context,
        ref,
      );
      if (!hasPermission) return;

      final parent = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose parent location',
      );
      if (parent == null) return;

      final path = '${parent.replaceFirst(RegExp(r'/$'), '')}/$folderName';
      await _ensureWritableFolder(path);
      ref.read(_selectedPathProvider.notifier).state = path;
      ref.read(_selectedUriProvider.notifier).state = path;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create storage folder: $e')),
        );
      }
    }
  }

  Future<void> _continue(BuildContext context, WidgetRef ref) async {
    final path = ref.read(_selectedPathProvider);
    final uri = ref.read(_selectedUriProvider);
    if (path == null) return;

    ref.read(_isLoadingProvider.notifier).state = true;

    try {
      await _ensureWritableFolder(path);
      final storageService = ref.read(storageServiceProvider);
      await storageService.completeOnboarding(
        folderUri: uri ?? path,
        folderPath: path,
      );
      await ref
          .read(conversationsRepositoryProvider)
          .restoreConversationsFromStorage();
      ref.read(conversationsRefreshProvider.notifier).state++;

      if (context.mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Storage folder is not writable: $e')),
        );
      }
    } finally {
      ref.read(_isLoadingProvider.notifier).state = false;
    }
  }

  Future<void> _ensureWritableFolder(String path) async {
    final dir = Directory(path);
    await dir.create(recursive: true);

    final modelsDir = Directory('${dir.path}/models');
    final chatsDir = Directory('${dir.path}/chats');
    await modelsDir.create(recursive: true);
    await chatsDir.create(recursive: true);

    final probe = File('${dir.path}/.lokus_write_test');
    await probe.writeAsString('ok', flush: true);
    if (await probe.exists()) {
      await probe.delete();
    }
  }

  Future<void> _useDefaultStorage(WidgetRef ref) async {
    final path = await _defaultStoragePath();
    await _ensureWritableFolder(path);
    ref.read(_selectedPathProvider.notifier).state = path;
    ref.read(_selectedUriProvider.notifier).state = path;
  }

  Future<bool> _ensureExternalStoragePermission(
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (!Platform.isAndroid) return true;
    if (await Permission.manageExternalStorage.isGranted) return true;

    final status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;

    if (!context.mounted) return false;
    final useAppStorage = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: Text('Storage Access Needed'),
        content: Text(
          'Choosing any folder requires Android all-files access. You can use the app storage folder without this permission.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Use App Storage'),
          ),
          ElevatedButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(ctx, false);
            },
            child: Text('Open Settings'),
          ),
        ],
      ),
    );

    if (useAppStorage == true) {
      await _useDefaultStorage(ref);
      return false;
    }
    return false;
  }

  Future<String> _defaultStoragePath() async {
    final baseDir = Platform.isAndroid
        ? await getExternalStorageDirectory()
        : await getApplicationDocumentsDirectory();
    if (baseDir == null) {
      throw FileSystemException('Device storage is not available.');
    }
    return '${baseDir.path}/Lokus';
  }
}

class _StorageInfoRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _InfoCard(
            icon: Icons.storage_rounded,
            label: 'Models',
            sub: 'GGUF files',
            color: AppTheme.accent,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _InfoCard(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'History',
            sub: 'Conversations',
            color: AppTheme.textSecondary,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _InfoCard(
            icon: Icons.tune_rounded,
            label: 'Config',
            sub: 'System prompts',
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            sub,
            style: TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedFolderCard extends StatelessWidget {
  final String path;
  const _SelectedFolderCard({required this.path});

  @override
  Widget build(BuildContext context) {
    final displayPath =
        path.length > 42 ? '...${path.substring(path.length - 42)}' : path;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentDim),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.accentDim,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.folder_rounded,
              color: AppTheme.accent,
              size: 18,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected Folder',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.accentLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  displayPath,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textPrimary,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            Icons.check_circle_rounded,
            color: AppTheme.success,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _EmptyFolderCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.border,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.folder_off_outlined,
              color: AppTheme.textTertiary, size: 20),
          SizedBox(width: 12),
          Text(
            'No folder selected',
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _FolderButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FolderButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppTheme.accent),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

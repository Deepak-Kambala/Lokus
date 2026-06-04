import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/hive_constants.dart';
import '../../../../services/storage_service.dart';
import '../../../conversations/providers/conversations_provider.dart';
import '../../../models/data/repositories/models_repository.dart';
import '../../../models/providers/models_provider.dart';

final settingsRefreshProvider = StateProvider<int>((ref) => 0);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(settingsRefreshProvider);
    final storageService = ref.read(storageServiceProvider);
    final folderPath = storageService.storageFolderPath ?? 'Not set';
    final language = storageService.getSetting<String>(
      HiveConstants.appLanguage,
      defaultValue: 'Auto',
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Settings'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),
      body: ListView(
        children: [
          _SectionHeader('AI'),
          _SettingsTile(
            icon: Icons.memory_rounded,
            title: 'Models',
            subtitle: 'Manage downloaded models',
            onTap: () => context.push('/models'),
          ),
          _SettingsTile(
            icon: Icons.tune_rounded,
            title: 'System Prompts',
            subtitle: 'Manage reusable system prompts',
            onTap: () => _showSystemPromptsSheet(context),
          ),
          _SectionHeader('STORAGE'),
          _SettingsTile(
            icon: Icons.folder_rounded,
            title: 'Storage Location',
            subtitle: _truncatePath(folderPath),
            onTap: () => _showChangeFolderSheet(context, ref),
          ),
          _SettingsTile(
            icon: Icons.storage_rounded,
            title: 'Storage Usage',
            subtitle: 'View storage breakdown',
            onTap: () {},
          ),
          _SectionHeader('APP'),
          _SettingsTile(
            icon: Icons.language_rounded,
            title: 'Response Language',
            subtitle: language,
            onTap: () => _showLanguageSheet(context, ref),
          ),
          _SettingsTile(
            icon: Icons.upload_rounded,
            title: 'Export Chats',
            subtitle: 'Export conversations as JSON',
            onTap: () => _exportChats(context, ref),
          ),
          _SectionHeader('INFO'),
          _SettingsTile(
            icon: Icons.shield_outlined,
            title: 'Privacy Policy',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.help_outline_rounded,
            title: 'FAQ',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'About',
            subtitle: 'Lokus v${AppConstants.appVersion}',
            onTap: () => _showAboutDialog(context),
          ),
          const SizedBox(height: 40),
          Center(
            child: Text(
              'Lokus ${AppConstants.appVersion}\nAll AI runs locally on device',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textTertiary,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _truncatePath(String path) {
    if (path.length > 44) return '...${path.substring(path.length - 44)}';
    return path;
  }

  void _showSystemPromptsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => _SystemPromptsSheet(scrollController: ctrl),
      ),
    );
  }

  void _showChangeFolderSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => const _ChangeFolderSheet(),
    );
  }

  void _showLanguageSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _LanguageSheet(ref: ref),
    );
  }

  Future<void> _exportChats(BuildContext context, WidgetRef ref) async {
    try {
      final file = await ref
          .read(conversationsRepositoryProvider)
          .exportAllConversations();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chats exported to ${file.path}')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: AppConstants.appName,
      applicationVersion: AppConstants.appVersion,
      applicationIcon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppTheme.accentSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.auto_awesome_rounded,
            color: AppTheme.accent, size: 24),
      ),
      children: const [
        SizedBox(height: 8),
        Text(
          'A local AI chat app. All models run fully on-device — no cloud, no data sent anywhere.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppTheme.textTertiary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppTheme.border),
        ),
        child: Icon(icon, size: 16, color: AppTheme.textSecondary),
      ),
      title: Text(title),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: onTap != null
          ? const Icon(Icons.chevron_right_rounded,
              size: 18, color: AppTheme.textTertiary)
          : null,
    );
  }
}

class _LanguageSheet extends StatelessWidget {
  final WidgetRef ref;
  const _LanguageSheet({required this.ref});

  static const _languages = [
    'Auto',
    'English (United States)',
    'English (United Kingdom)',
    'Hindi (India)',
    'Spanish (Spain)',
    'French (France)',
    'German (Germany)',
    'Italian (Italy)',
    'Portuguese (Brazil)',
    'Dutch (Netherlands)',
    'Polish (Poland)',
    'Turkish (Turkey)',
    'Japanese (Japan)',
    'Korean (South Korea)',
    'Chinese (China)',
    'Arabic (United Arab Emirates)',
    'Indonesian (Indonesia)',
  ];

  @override
  Widget build(BuildContext context) {
    final storage = ref.read(storageServiceProvider);
    final selected = storage.getSetting<String>(
      HiveConstants.appLanguage,
      defaultValue: 'Auto',
    );

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(color: AppTheme.surface),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Response Language',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _languages.length,
                itemBuilder: (context, index) {
                  final language = _languages[index];
                  final isSelected = language == selected;
                  return ListTile(
                    title: Text(language),
                    subtitle: language == 'Auto'
                        ? const Text('Use the same language as the prompt')
                        : null,
                    trailing: isSelected
                        ? const Icon(Icons.check_rounded,
                            color: AppTheme.accent)
                        : null,
                    onTap: () async {
                      await storage.setSetting(
                        HiveConstants.appLanguage,
                        language,
                      );
                      ref.read(settingsRefreshProvider.notifier).state++;
                      if (context.mounted) Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemPromptsSheet extends StatelessWidget {
  final ScrollController scrollController;
  const _SystemPromptsSheet({required this.scrollController});

  static const _presets = [
    (
      'Helpful Assistant',
      'You are a helpful, harmless, and honest AI assistant.'
    ),
    (
      'Code Expert',
      'You are an expert software engineer. Write clean, efficient, well-documented code. Always explain your approach.'
    ),
    (
      'Creative Writer',
      'You are a creative writing assistant. Help craft engaging stories, vivid descriptions, and compelling characters.'
    ),
    (
      'Socratic Teacher',
      'You are a teacher who uses the Socratic method. Guide the student to discover answers through thoughtful questions.'
    ),
    (
      'Concise Analyst',
      'You are an analytical assistant. Provide concise, structured answers. Use bullet points and headers when appropriate.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'System Prompts',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Spacer(),
                Icon(Icons.add_rounded, color: AppTheme.accent),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _presets.length,
              separatorBuilder: (_, __) =>
                  Container(height: 1, color: AppTheme.borderSubtle),
              itemBuilder: (_, i) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_presets[i].$1),
                  subtitle: Text(
                    _presets[i].$2,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppTheme.textTertiary,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangeFolderSheet extends ConsumerWidget {
  const _ChangeFolderSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Change Storage Folder',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Models already downloaded will need to be re-downloaded if you change the folder.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _chooseFolder(context, ref),
              icon: const Icon(Icons.folder_open_rounded, size: 16),
              label: const Text('Choose Folder'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _createFolder(context, ref),
              icon: const Icon(Icons.create_new_folder_outlined, size: 16),
              label: const Text('Create Folder'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Future<void> _chooseFolder(BuildContext context, WidgetRef ref) async {
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
      await _resetModelsAfterStorageChange(ref);
      await ref.read(storageServiceProvider).updateStorageFolder(
            folderUri: path,
            folderPath: path,
          );

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage folder updated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Storage folder is not writable: $e')),
        );
      }
    }
  }

  Future<void> _createFolder(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: 'Lokus');
    final folderName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text('Create Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Folder name',
            hintText: 'Lokus',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Create'),
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
      await _resetModelsAfterStorageChange(ref);
      await ref.read(storageServiceProvider).updateStorageFolder(
            folderUri: path,
            folderPath: path,
          );

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage folder updated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Storage folder is not writable: $e')),
        );
      }
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
    await _resetModelsAfterStorageChange(ref);
    await ref.read(storageServiceProvider).updateStorageFolder(
          folderUri: path,
          folderPath: path,
        );
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
        title: const Text('Storage Access Needed'),
        content: const Text(
          'Choosing any folder requires Android all-files access. You can use the app storage folder without this permission.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Use App Storage'),
          ),
          ElevatedButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(ctx, false);
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );

    if (useAppStorage == true) {
      await _useDefaultStorage(ref);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage folder updated')),
        );
      }
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
}

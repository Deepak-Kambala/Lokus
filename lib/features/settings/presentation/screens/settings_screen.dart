import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../services/storage_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storageService = ref.read(storageServiceProvider);
    final folderPath = storageService.storageFolderPath ?? 'Not set';

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
            title: 'Language',
            subtitle: 'English',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.upload_rounded,
            title: 'Export Chats',
            subtitle: 'Export conversations as JSON',
            onTap: () {},
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
              label: const Text('Choose New Folder'),
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
      final hasPermission = await _ensureStoragePermission(context);
      if (!hasPermission) return;

      final path = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose Lokus storage folder',
      );
      if (path == null) return;

      await _ensureWritableFolder(path);
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

  Future<bool> _ensureStoragePermission(BuildContext context) async {
    return true;
  }
}

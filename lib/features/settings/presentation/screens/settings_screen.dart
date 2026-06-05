import 'dart:io';
import 'dart:math' as math;

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
    final activePrompt = storageService.getSetting<String>(
      HiveConstants.activeSystemPromptTitle,
      defaultValue: 'None',
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text('Settings'),
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
            subtitle: activePrompt == 'None'
                ? 'Manage reusable prompts'
                : activePrompt,
            onTap: () => _showSystemPromptsSheet(context, ref),
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
            onTap: () => _showStorageUsageSheet(context, ref),
          ),
          _SectionHeader('APP'),
          _SettingsTile(
            icon: Icons.language_rounded,
            title: 'Response Language',
            subtitle: language,
            onTap: () => _showLanguageSheet(context, ref),
          ),
          _SectionHeader('INFO'),
          _SettingsTile(
            icon: Icons.shield_outlined,
            title: 'Privacy Policy',
            onTap: () => _showPrivacySheet(context),
          ),
          _SettingsTile(
            icon: Icons.help_outline_rounded,
            title: 'FAQ',
            onTap: () => _showFaqSheet(context),
          ),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'About',
            subtitle: 'Lokus v${AppConstants.appVersion}',
            onTap: () => _showAboutSheet(context),
          ),
          SizedBox(height: 40),
          Center(
            child: Text(
              'Lokus ${AppConstants.appVersion}\nAll AI runs locally on device',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textTertiary,
                height: 1.6,
              ),
            ),
          ),
          SizedBox(height: 32),
        ],
      ),
    );
  }

  String _truncatePath(String path) {
    if (path.length > 44) return '...${path.substring(path.length - 44)}';
    return path;
  }

  void _showSystemPromptsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => _SystemPromptsSheet(
          scrollController: ctrl,
          ref: ref,
        ),
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

  void _showStorageUsageSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.78,
        maxChildSize: 0.92,
        minChildSize: 0.5,
        expand: false,
        builder: (_, ctrl) => _StorageUsageSheet(
          scrollController: ctrl,
          storagePath: ref.read(storageServiceProvider).storageFolderPath,
        ),
      ),
    );
  }

  void _showPrivacySheet(BuildContext context) {
    _showInfoSheet(
      context: context,
      title: 'Privacy',
      icon: Icons.shield_outlined,
      children: [
        _InfoParagraph(
          'Lokus runs downloaded GGUF models on your device. Chats, selected folders, model files, and exports stay in local storage unless you manually share them.',
        ),
        _InfoParagraph(
          'The app uses the internet only to download model files from the model source you choose. Prompts and responses are not sent to a Lokus server.',
        ),
        _InfoParagraph(
          'If you export chats, the JSON file is saved inside your selected storage folder. Delete that file when you no longer need it.',
        ),
      ],
    );
  }

  void _showFaqSheet(BuildContext context) {
    _showInfoSheet(
      context: context,
      title: 'FAQ',
      icon: Icons.help_outline_rounded,
      children: [
        _FaqItem(
          question: 'Why do I need to download a model first?',
          answer:
              'Lokus runs AI locally. A downloaded GGUF model is the engine that generates responses on your phone.',
        ),
        _FaqItem(
          question: 'Why are some models slow?',
          answer:
              'Speed depends on model size, quantization, RAM, storage speed, and your device CPU. Smaller 0.5B to 2B models usually work best on phones.',
        ),
        _FaqItem(
          question: 'Can I use Lokus offline?',
          answer:
              'Yes. After the model is downloaded, chat runs offline. Internet is only needed for downloading models.',
        ),
        _FaqItem(
          question: 'Where are my chats stored?',
          answer:
              'Chats are stored locally inside your selected Lokus storage folder and mirrored in app storage for fast loading.',
        ),
        _FaqItem(
          question: 'Why does changing folder require re-download?',
          answer:
              'The app checks models in the active storage folder. If the file is not there, it marks the model as available for download again.',
        ),
        _FaqItem(
          question: 'Why does the app ask for storage access?',
          answer:
              'Android requires permission before an app can write large model files into folders you choose outside app storage.',
        ),
        _FaqItem(
          question: 'Which language should I select?',
          answer:
              'Use Auto to match your prompt language. Select a specific language when you want every response in that language.',
        ),
        _FaqItem(
          question: 'Why do answers sometimes stop early?',
          answer:
              'Local models can stop when they reach an end token, context limit, or device memory pressure. Try a smaller model or a shorter prompt.',
        ),
      ],
    );
  }

  void _showAboutSheet(BuildContext context) {
    _showInfoSheet(
      context: context,
      title: 'About Lokus',
      icon: Icons.info_outline_rounded,
      children: [
        Center(
          child: Text(
            'Lokus',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        SizedBox(height: 4),
        Center(
          child: Text(
            'Version ${AppConstants.appVersion}',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ),
        SizedBox(height: 20),
        _InfoParagraph(
          'Lokus is a private local AI chat app for running downloaded GGUF models directly on your device.',
        ),
        _InfoParagraph(
          'Models, chats, and exports stay in the storage location you choose. Performance depends on your device and the model size.',
        ),
      ],
    );
  }

  void _showInfoSheet({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<Widget> children,
    Widget? action,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        maxChildSize: 0.9,
        minChildSize: 0.45,
        expand: false,
        builder: (_, ctrl) => _InfoSheet(
          title: title,
          icon: icon,
          action: action,
          scrollController: ctrl,
          children: children,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 24, 16, 6),
      child: Text(
        title,
        style: TextStyle(
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
          ? Icon(Icons.chevron_right_rounded,
              size: 18, color: AppTheme.textTertiary)
          : null,
    );
  }
}

class _StorageUsageSheet extends StatefulWidget {
  final ScrollController scrollController;
  final String? storagePath;

  const _StorageUsageSheet({
    required this.scrollController,
    required this.storagePath,
  });

  @override
  State<_StorageUsageSheet> createState() => _StorageUsageSheetState();
}

class _StorageUsageSheetState extends State<_StorageUsageSheet> {
  late Future<_StorageSnapshot> _snapshotFuture;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _collectStorage(widget.storagePath);
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      child: FutureBuilder<_StorageSnapshot>(
        future: _snapshotFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }

          if (snapshot.hasError) {
            return _EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Storage unavailable',
              message: snapshot.error.toString(),
            );
          }

          final data = snapshot.data!;
          if (!data.isConfigured) {
            return const _EmptyState(
              icon: Icons.folder_off_outlined,
              title: 'No storage folder',
              message: 'Choose a storage location before viewing usage.',
            );
          }

          return ListView(
            controller: widget.scrollController,
            padding: EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              const _SheetHeader(
                icon: Icons.storage_rounded,
                title: 'Storage Usage',
              ),
              SizedBox(height: 18),
              _UsageHero(snapshot: data),
              SizedBox(height: 18),
              _MetricGrid(snapshot: data),
              SizedBox(height: 18),
              const _PanelTitle('Breakdown'),
              SizedBox(height: 8),
              ...data.categories.map(
                (category) => _StorageCategoryRow(
                  category: category,
                  totalBytes: data.totalBytes,
                ),
              ),
              SizedBox(height: 18),
              const _PanelTitle('Location'),
              SizedBox(height: 8),
              _PathPanel(path: data.path!),
            ],
          );
        },
      ),
    );
  }

  Future<_StorageSnapshot> _collectStorage(String? rootPath) async {
    if (rootPath == null || rootPath.isEmpty) {
      return const _StorageSnapshot.notConfigured();
    }

    final root = Directory(rootPath);
    if (!await root.exists()) {
      return _StorageSnapshot(
        path: rootPath,
        totalBytes: 0,
        fileCount: 0,
        folderCount: 0,
        categories: const [],
      );
    }

    final total = await _scanDirectory(root);
    final models = await _scanDirectory(Directory('${root.path}/models'));
    final chats = await _scanDirectory(Directory('${root.path}/chats'));
    final exports = await _scanDirectory(Directory('${root.path}/exports'));
    final knownBytes = models.bytes + chats.bytes + exports.bytes;
    final otherBytes = math.max(0, total.bytes - knownBytes);

    return _StorageSnapshot(
      path: rootPath,
      totalBytes: total.bytes,
      fileCount: total.fileCount,
      folderCount: total.folderCount,
      categories: [
        _StorageCategory(
          label: 'Models',
          detail: '${models.fileCount} files',
          bytes: models.bytes,
          icon: Icons.memory_rounded,
          tone: AppTheme.accent,
        ),
        _StorageCategory(
          label: 'Chats',
          detail: '${chats.fileCount} files',
          bytes: chats.bytes,
          icon: Icons.chat_bubble_outline_rounded,
          tone: Color(0xFFD8D8DC),
        ),
        _StorageCategory(
          label: 'Exports',
          detail: '${exports.fileCount} files',
          bytes: exports.bytes,
          icon: Icons.upload_file_rounded,
          tone: Color(0xFFAFAFB5),
        ),
        _StorageCategory(
          label: 'Other',
          detail: 'Cache, metadata, partial files',
          bytes: otherBytes,
          icon: Icons.more_horiz_rounded,
          tone: Color(0xFF77777E),
        ),
      ],
    );
  }

  Future<_DirectoryStats> _scanDirectory(Directory dir) async {
    var bytes = 0;
    var files = 0;
    var folders = 0;

    try {
      if (!await dir.exists()) return const _DirectoryStats();
      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        try {
          if (entity is File) {
            bytes += await entity.length();
            files++;
          } else if (entity is Directory) {
            folders++;
          }
        } catch (_) {
          continue;
        }
      }
    } catch (_) {
      return _DirectoryStats(
        bytes: bytes,
        fileCount: files,
        folderCount: folders,
      );
    }

    return _DirectoryStats(
      bytes: bytes,
      fileCount: files,
      folderCount: folders,
    );
  }
}

class _UsageHero extends StatelessWidget {
  final _StorageSnapshot snapshot;
  const _UsageHero({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Local data',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            _formatBytes(snapshot.totalBytes),
            style: TextStyle(
              fontSize: 30,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 14),
          _StackedUsageBar(snapshot: snapshot),
        ],
      ),
    );
  }
}

class _StackedUsageBar extends StatelessWidget {
  final _StorageSnapshot snapshot;
  const _StackedUsageBar({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final visible = snapshot.categories.where((c) => c.bytes > 0).toList();
    if (visible.isEmpty) {
      return Container(
        height: 12,
        decoration: BoxDecoration(
          color: AppTheme.surfaceHighlight,
          borderRadius: BorderRadius.circular(6),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 12,
        child: Row(
          children: visible.map((category) {
            final flex = math.max(
              1,
              (category.bytes / snapshot.totalBytes * 1000).round(),
            );
            return Expanded(
              flex: flex,
              child: Container(color: category.tone),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final _StorageSnapshot snapshot;
  const _MetricGrid({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricBox(
            label: 'Files',
            value: snapshot.fileCount.toString(),
            icon: Icons.insert_drive_file_outlined,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _MetricBox(
            label: 'Folders',
            value: snapshot.folderCount.toString(),
            icon: Icons.folder_outlined,
          ),
        ),
      ],
    );
  }
}

class _MetricBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricBox({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StorageCategoryRow extends StatelessWidget {
  final _StorageCategory category;
  final int totalBytes;

  const _StorageCategoryRow({
    required this.category,
    required this.totalBytes,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = totalBytes == 0 ? 0.0 : category.bytes / totalBytes;
    final percent = '${(ratio * 100).toStringAsFixed(ratio < 0.01 ? 1 : 0)}%';

    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: Icon(category.icon, size: 16, color: category.tone),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        category.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      _formatBytes(category.bytes),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  '$percent  •  ${category.detail}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textTertiary,
                  ),
                ),
                SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: ratio.clamp(0.0, 1.0),
                    color: category.tone,
                    backgroundColor: AppTheme.surfaceHighlight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PathPanel extends StatelessWidget {
  final String path;
  const _PathPanel({required this.path});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: SelectableText(
        path,
        style: TextStyle(
          fontSize: 12,
          color: AppTheme.textSecondary,
          height: 1.4,
        ),
      ),
    );
  }
}

class _InfoSheet extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? action;
  final ScrollController scrollController;
  final List<Widget> children;

  const _InfoSheet({
    required this.title,
    required this.icon,
    required this.scrollController,
    required this.children,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      child: ListView(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          _SheetHeader(icon: icon, title: title, action: action),
          SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}

class _SheetShell extends StatelessWidget {
  final Widget child;
  const _SheetShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? action;

  const _SheetHeader({
    required this.icon,
    required this.title,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: Icon(icon, size: 17, color: AppTheme.textPrimary),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

class _PanelTitle extends StatelessWidget {
  final String title;
  const _PanelTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        color: AppTheme.textSecondary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _InfoParagraph extends StatelessWidget {
  final String text;
  const _InfoParagraph(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          height: 1.5,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqItem({
    required this.question,
    required this.answer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: EdgeInsets.fromLTRB(14, 0, 14, 14),
          iconColor: AppTheme.textSecondary,
          collapsedIconColor: AppTheme.textTertiary,
          title: Text(
            question,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                answer,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: AppTheme.textTertiary),
            SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StorageSnapshot {
  final String? path;
  final int totalBytes;
  final int fileCount;
  final int folderCount;
  final List<_StorageCategory> categories;

  const _StorageSnapshot({
    required this.path,
    required this.totalBytes,
    required this.fileCount,
    required this.folderCount,
    required this.categories,
  });

  const _StorageSnapshot.notConfigured()
      : path = null,
        totalBytes = 0,
        fileCount = 0,
        folderCount = 0,
        categories = const [];

  bool get isConfigured => path != null && path!.isNotEmpty;
}

class _DirectoryStats {
  final int bytes;
  final int fileCount;
  final int folderCount;

  const _DirectoryStats({
    this.bytes = 0,
    this.fileCount = 0,
    this.folderCount = 0,
  });
}

class _StorageCategory {
  final String label;
  final String detail;
  final int bytes;
  final IconData icon;
  final Color tone;

  const _StorageCategory({
    required this.label,
    required this.detail,
    required this.bytes,
    required this.icon,
    required this.tone,
  });
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var index = 0;
  while (value >= 1024 && index < units.length - 1) {
    value /= 1024;
    index++;
  }
  final decimals = value >= 10 || index == 0 ? 0 : 1;
  return '${value.toStringAsFixed(decimals)} ${units[index]}';
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
        decoration: BoxDecoration(color: AppTheme.surface),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
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
                        ? Text('Use the same language as the prompt')
                        : null,
                    trailing: isSelected
                        ? Icon(Icons.check_rounded, color: AppTheme.accent)
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

class _SystemPromptsSheet extends StatefulWidget {
  final ScrollController scrollController;
  final WidgetRef ref;
  const _SystemPromptsSheet({
    required this.scrollController,
    required this.ref,
  });

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
  State<_SystemPromptsSheet> createState() => _SystemPromptsSheetState();
}

class _SystemPromptsSheetState extends State<_SystemPromptsSheet> {
  late List<(String, String)> _prompts;
  late String _activeTitle;

  @override
  void initState() {
    super.initState();
    final storage = widget.ref.read(storageServiceProvider);
    _prompts = _loadPrompts(storage);
    _activeTitle = storage.getSetting<String>(
      HiveConstants.activeSystemPromptTitle,
      defaultValue: 'None',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
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
                IconButton(
                  tooltip: 'Add prompt',
                  onPressed: _addPrompt,
                  icon: Icon(Icons.add_rounded, color: AppTheme.accent),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              controller: widget.scrollController,
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: _prompts.length + 1,
              separatorBuilder: (_, __) =>
                  Container(height: 1, color: AppTheme.borderSubtle),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('None'),
                    subtitle: Text('Use only the default model behavior'),
                    trailing: _activeTitle == 'None'
                        ? Icon(Icons.check_rounded, color: AppTheme.accent)
                        : null,
                    onTap: () => _selectPrompt('None', ''),
                  );
                }
                final prompt = _prompts[i - 1];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(prompt.$1),
                  subtitle: Text(
                    prompt.$2,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: _activeTitle == prompt.$1
                      ? Icon(Icons.check_rounded, color: AppTheme.accent)
                      : Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: AppTheme.textTertiary,
                        ),
                  onTap: () => _selectPrompt(prompt.$1, prompt.$2),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<(String, String)> _loadPrompts(StorageService storage) {
    final raw = storage.getSetting<List>(
      HiveConstants.systemPrompts,
      defaultValue: const [],
    );
    final custom = raw
        .whereType<Map>()
        .map((item) => (
              item['title']?.toString() ?? '',
              item['prompt']?.toString() ?? '',
            ))
        .where((item) => item.$1.trim().isNotEmpty && item.$2.trim().isNotEmpty)
        .toList();
    return [..._SystemPromptsSheet._presets, ...custom];
  }

  Future<void> _selectPrompt(String title, String prompt) async {
    final storage = widget.ref.read(storageServiceProvider);
    await storage.setSetting(HiveConstants.activeSystemPromptTitle, title);
    await storage.setSetting(HiveConstants.activeSystemPromptText, prompt);
    widget.ref.read(settingsRefreshProvider.notifier).state++;
    setState(() => _activeTitle = title);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _addPrompt() async {
    final titleCtrl = TextEditingController();
    final promptCtrl = TextEditingController();
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: Text('Add System Prompt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(labelText: 'Name'),
              autofocus: true,
            ),
            SizedBox(height: 12),
            TextField(
              controller: promptCtrl,
              decoration: InputDecoration(labelText: 'Prompt'),
              minLines: 4,
              maxLines: 7,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final title = titleCtrl.text.trim();
              final prompt = promptCtrl.text.trim();
              if (title.isEmpty || prompt.isEmpty) return;
              Navigator.pop(ctx, (title, prompt));
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
    titleCtrl.dispose();
    promptCtrl.dispose();
    if (result == null) return;

    final storage = widget.ref.read(storageServiceProvider);
    final raw = storage.getSetting<List>(
      HiveConstants.systemPrompts,
      defaultValue: const [],
    );
    final updated = [
      ...raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)),
      {'title': result.$1, 'prompt': result.$2},
    ];
    await storage.setSetting(HiveConstants.systemPrompts, updated);
    await storage.setSetting(HiveConstants.activeSystemPromptTitle, result.$1);
    await storage.setSetting(HiveConstants.activeSystemPromptText, result.$2);
    widget.ref.read(settingsRefreshProvider.notifier).state++;
    setState(() {
      _prompts = _loadPrompts(storage);
      _activeTitle = result.$1;
    });
  }
}

class _ChangeFolderSheet extends ConsumerWidget {
  const _ChangeFolderSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            'Change Storage Folder',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Models already downloaded will need to be re-downloaded if you change the folder.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
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
          SnackBar(content: Text('Storage folder updated')),
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
      await _resetModelsAfterStorageChange(ref);
      await ref.read(storageServiceProvider).updateStorageFolder(
            folderUri: path,
            folderPath: path,
          );

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Storage folder updated')),
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
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Storage folder updated')),
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

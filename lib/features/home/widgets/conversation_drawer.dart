import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../chat/domain/entities/conversation.dart';
import '../../conversations/providers/conversations_provider.dart';

final _drawerSearchProvider = StateProvider<String>((ref) => '');

class ConversationDrawer extends ConsumerStatefulWidget {
  const ConversationDrawer({super.key});

  @override
  ConsumerState<ConversationDrawer> createState() => _ConversationDrawerState();
}

class _ConversationDrawerState extends ConsumerState<ConversationDrawer> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationsListProvider);
    final searchQuery = ref.watch(_drawerSearchProvider);

    final filtered = searchQuery.isEmpty
        ? conversations
        : conversations
            .where((c) =>
                c.title.toLowerCase().contains(searchQuery.toLowerCase()))
            .toList();

    final pinned = filtered.where((c) => c.isPinned).toList();
    final unpinned = filtered.where((c) => !c.isPinned).toList();
    final today = unpinned.where(_isToday).toList();
    final recent = unpinned.where((c) => !_isToday(c)).toList();

    return Drawer(
      backgroundColor: AppTheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            _DrawerHeader(),
            _SearchBar(controller: _searchController),
            Expanded(
              child: conversations.isEmpty
                  ? _EmptyState()
                  : ListView(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      children: [
                        if (pinned.isNotEmpty) ...[
                          _SectionLabel('Pinned'),
                          ...pinned.map((c) => _ConversationTile(convo: c)),
                          SizedBox(height: 8),
                        ],
                        if (today.isNotEmpty) ...[
                          _SectionLabel('Today'),
                          ...today.map((c) => _ConversationTile(convo: c)),
                          SizedBox(height: 8),
                        ],
                        if (recent.isNotEmpty) ...[
                          _SectionLabel('Recent'),
                          ...recent.map((c) => _ConversationTile(convo: c)),
                        ],
                      ],
                    ),
            ),
            _DrawerFooter(),
          ],
        ),
      ),
    );
  }

  bool _isToday(Conversation conversation) {
    final now = DateTime.now();
    final updated = conversation.updatedAt.toLocal();
    return updated.year == now.year &&
        updated.month == now.month &&
        updated.day == now.day;
  }
}

class _DrawerHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.accentSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 15,
              color: AppTheme.accent,
            ),
          ),
          SizedBox(width: 10),
          Text(
            'Lokus',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          Spacer(),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Icon(
              Icons.close_rounded,
              size: 18,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends ConsumerWidget {
  final TextEditingController controller;
  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        controller: controller,
        onChanged: (v) => ref.read(_drawerSearchProvider.notifier).state = v,
        cursorColor: AppTheme.accent,
        style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search conversations...',
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 16,
            color: AppTheme.textSecondary,
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 10),
          filled: true,
          fillColor: AppTheme.surfaceElevated,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppTheme.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppTheme.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppTheme.accent),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 12, 8, 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.textTertiary,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  final Conversation convo;
  const _ConversationTile({required this.convo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        context.push('/chat/${convo.id}');
      },
      onLongPress: () => _showOptions(context, ref),
      child: Container(
        margin: EdgeInsets.only(bottom: 2),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            if (convo.isPinned)
              Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.push_pin_rounded,
                    size: 12, color: AppTheme.accent),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    convo.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (convo.lastMessage != null) ...[
                    SizedBox(height: 2),
                    Text(
                      convo.lastMessage!,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 8),
            Text(
              _formatDate(convo.updatedAt),
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.month}/${dt.day}';
  }

  void _showOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (ctx) => _ConvoOptionsSheet(
        convo: convo,
        drawerContext: context,
      ),
    );
  }
}

class _ConvoOptionsSheet extends ConsumerWidget {
  final Conversation convo;
  final BuildContext drawerContext;
  const _ConvoOptionsSheet({
    required this.convo,
    required this.drawerContext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(
                convo.isPinned
                    ? Icons.push_pin_outlined
                    : Icons.push_pin_rounded,
                size: 18,
                color: AppTheme.textSecondary,
              ),
              title: Text(
                convo.isPinned ? 'Unpin' : 'Pin',
                style: TextStyle(color: AppTheme.textPrimary),
              ),
              onTap: () {
                ref.read(conversationsRepositoryProvider).togglePin(convo.id);
                ref.read(conversationsRefreshProvider.notifier).state++;
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.edit_outlined,
                size: 18,
                color: AppTheme.textSecondary,
              ),
              title: Text(
                'Rename',
                style: TextStyle(color: AppTheme.textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (drawerContext.mounted) {
                    _showRenameDialog(drawerContext);
                  }
                });
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded,
                  size: 18, color: AppTheme.error),
              title: Text(
                'Delete',
                style: TextStyle(color: AppTheme.error),
              ),
              onTap: () {
                ref
                    .read(conversationsRepositoryProvider)
                    .deleteConversation(convo.id);
                ref.read(conversationsRefreshProvider.notifier).state++;
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.download_rounded,
                size: 18,
                color: AppTheme.textSecondary,
              ),
              title: Text(
                'Export',
                style: TextStyle(color: AppTheme.textPrimary),
              ),
              onTap: () async {
                Navigator.pop(context);
                try {
                  final file = await ref
                      .read(conversationsRepositoryProvider)
                      .exportConversation(convo.id);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Chat exported to ${file.path}')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Export failed: $e')),
                  );
                }
              },
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _showRenameDialog(BuildContext context) async {
    final controller = TextEditingController(text: convo.title);
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surfaceElevated,
          title: Text(
            'Rename Chat',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            cursorColor: AppTheme.accent,
            style: TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(labelText: 'Title'),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saveRename(ctx, container, controller),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
            ElevatedButton(
              onPressed: () => _saveRename(ctx, container, controller),
              child: Text('Save'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _saveRename(
    BuildContext context,
    ProviderContainer container,
    TextEditingController controller,
  ) async {
    final title = controller.text.trim();
    if (title.isEmpty) return;
    await container
        .read(conversationsRepositoryProvider)
        .renameConversation(convo.id, title);
    container.read(conversationsRefreshProvider.notifier).state++;
    final current = container.read(currentConversationProvider);
    if (current?.id == convo.id) {
      final updated =
          container.read(conversationsRepositoryProvider).getById(convo.id);
      container.read(currentConversationProvider.notifier).state = updated;
    }
    if (context.mounted) {
      Navigator.pop(context);
    }
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 40, color: AppTheme.textTertiary),
          SizedBox(height: 12),
          Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Start a new chat to begin',
            style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _DrawerFooter extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.psychology_rounded, size: 18),
            title: Text(
              'Memory',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            onTap: () {
              Navigator.of(context).pop();
              context.push('/memory');
            },
          ),
          ListTile(
            leading: Icon(Icons.settings_outlined, size: 18),
            title: Text(
              'Settings',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            onTap: () {
              Navigator.of(context).pop();
              context.push('/settings');
            },
          ),
        ],
      ),
    );
  }
}


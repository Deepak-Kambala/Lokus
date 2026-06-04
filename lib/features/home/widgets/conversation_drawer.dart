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
    final recent = filtered.where((c) => !c.isPinned).toList();

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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      children: [
                        if (pinned.isNotEmpty) ...[
                          _SectionLabel('PINNED'),
                          ...pinned.map((c) => _ConversationTile(convo: c)),
                          const SizedBox(height: 8),
                        ],
                        if (recent.isNotEmpty) ...[
                          if (pinned.isNotEmpty) _SectionLabel('RECENT'),
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
}

class _DrawerHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.accentSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 15,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Lokus',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        controller: controller,
        onChanged: (v) =>
            ref.read(_drawerSearchProvider.notifier).state = v,
        style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search conversations...',
          prefixIcon: const Icon(Icons.search_rounded, size: 16),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          filled: true,
          fillColor: AppTheme.surfaceElevated,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.accent),
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
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
      child: Text(
        label,
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
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            if (convo.isPinned)
              const Padding(
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
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (convo.lastMessage != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      convo.lastMessage!,
                      style: const TextStyle(
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
            const SizedBox(width: 8),
            Text(
              _formatDate(convo.updatedAt),
              style: const TextStyle(
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
      builder: (ctx) => _ConvoOptionsSheet(convo: convo),
    );
  }
}

class _ConvoOptionsSheet extends ConsumerWidget {
  final Conversation convo;
  const _ConvoOptionsSheet({required this.convo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
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
            ),
            title: Text(convo.isPinned ? 'Unpin' : 'Pin'),
            onTap: () {
              ref
                  .read(conversationsRepositoryProvider)
                  .togglePin(convo.id);
              ref.read(conversationsRefreshProvider.notifier).state++;
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.drive_file_rename_outline_rounded, size: 18),
            title: const Text('Rename'),
            onTap: () {
              Navigator.pop(context);
              _showRenameDialog(context, ref);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, size: 18,
                color: AppTheme.error),
            title: const Text(
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
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: convo.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text('Rename Chat'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref
                    .read(conversationsRepositoryProvider)
                    .renameConversation(convo.id, controller.text);
                ref.read(conversationsRefreshProvider.notifier).state++;
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
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
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: ListTile(
        leading: const Icon(Icons.settings_outlined, size: 18),
        title: const Text(
          'Settings',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        onTap: () {
          Navigator.of(context).pop();
          context.push('/settings');
        },
      ),
    );
  }
}

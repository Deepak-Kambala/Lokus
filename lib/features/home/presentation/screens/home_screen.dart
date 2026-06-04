import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../conversations/providers/conversations_provider.dart';
import '../../../models/providers/models_provider.dart';
import '../../../models/domain/entities/ai_model.dart';
import '../../widgets/conversation_drawer.dart';
import '../../widgets/model_selector_button.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _inputController = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _inputController.addListener(() {
      final hasText = _inputController.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.background,
      drawer: const ConversationDrawer(),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          _buildInputArea(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.background,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded, color: AppTheme.textPrimary),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: const ModelSelectorButton(),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, color: AppTheme.textSecondary),
          tooltip: 'New Chat',
          onPressed: _startNewChat,
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppTheme.border),
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WelcomeHeader(),
          const SizedBox(height: 32),
          _WhatsNewCard(),
          const SizedBox(height: 24),
          _QuickStartGrid(onTap: _startWithPrompt),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: const Border(top: BorderSide(color: AppTheme.border)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        hintStyle: TextStyle(color: AppTheme.textTertiary),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                        isDense: true,
                      ),
                      maxLines: 5,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _hasText ? AppTheme.accent : AppTheme.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: _hasText ? AppTheme.accent : AppTheme.border,
              ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.arrow_upward_rounded,
                size: 18,
                color: _hasText ? Colors.black : AppTheme.textTertiary,
              ),
              onPressed: _hasText ? _sendMessage : null,
            ),
          ),
        ],
      ),
    );
  }

  void _startNewChat() {
    final model = ref.read(activeModelProvider);
    if (model == null) {
      _showNoModelDialog();
      return;
    }
    _createAndOpenChat(model, '');
  }

  void _startWithPrompt(String prompt) {
    _inputController.text = prompt;
    setState(() => _hasText = true);
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    final model = ref.read(activeModelProvider);
    if (model == null) {
      _showNoModelDialog();
      return;
    }

    _inputController.clear();
    _createAndOpenChat(model, text);
  }

  Future<void> _createAndOpenChat(AiModel model, String initialMessage) async {
    final repo = ref.read(conversationsRepositoryProvider);
    final convo = await repo.createConversation(
      modelId: model.id,
      modelName: model.name,
    );
    ref.read(conversationsRefreshProvider.notifier).state++;

    if (mounted) {
      context.push(
        '/chat/${convo.id}',
        extra: initialMessage.isNotEmpty ? initialMessage : null,
      );
    }
  }

  void _showNoModelDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text('No Model Selected'),
        content: const Text(
          'Please download and select an AI model to start chatting.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/models');
            },
            child: const Text('Browse Models'),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _WelcomeHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Good ${_greeting()},',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w400,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'How can I help today?',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                letterSpacing: -0.5,
              ),
        ),
      ],
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 18) return 'afternoon';
    return 'evening';
  }
}

class _WhatsNewCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.accentSurface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.accentDim),
                ),
                child: const Text(
                  "WHAT'S NEW",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentLight,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _NewsItem(
            icon: Icons.tune_rounded,
            title: 'Reusable system prompts',
            sub: 'Save and reuse custom system prompts across chats',
          ),
          const SizedBox(height: 12),
          _NewsItem(
            icon: Icons.language_rounded,
            title: 'Available in 28 languages',
            sub: 'Full UI localization now available',
          ),
          const SizedBox(height: 12),
          _NewsItem(
            icon: Icons.speed_rounded,
            title: 'Performance improvements',
            sub: 'Faster model loading and token generation',
          ),
        ],
      ),
    );
  }
}

class _NewsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;

  const _NewsItem({required this.icon, required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.surfaceHighlight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: AppTheme.accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickStartGrid extends StatelessWidget {
  final Function(String) onTap;
  const _QuickStartGrid({required this.onTap});

  static const _prompts = [
    ('Summarize a topic', Icons.article_outlined, 'Summarize the key concepts of '),
    ('Write code', Icons.code_rounded, 'Write a function that '),
    ('Explain something', Icons.lightbulb_outline_rounded, 'Explain how '),
    ('Brainstorm ideas', Icons.auto_awesome_outlined, 'Give me 10 ideas for '),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'QUICK START',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTheme.textTertiary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: _prompts.map((p) {
            return GestureDetector(
              onTap: () => onTap(p.$3),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    Icon(p.$2, size: 15, color: AppTheme.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p.$1,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

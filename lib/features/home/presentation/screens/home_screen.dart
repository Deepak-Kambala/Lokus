import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../core/constants/hive_constants.dart';
import '../../../../services/inference_service.dart';
import '../../../../services/storage_service.dart';
import '../../../conversations/providers/conversations_provider.dart';
import '../../../models/data/repositories/models_repository.dart';
import '../../../models/providers/models_provider.dart';
import '../../../models/domain/entities/ai_model.dart';
import '../../widgets/conversation_drawer.dart';
import '../../widgets/model_selector_button.dart';
import '../../widgets/new_chat_button.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await ref
          .read(conversationsRepositoryProvider)
          .removeEmptyConversations();
      await _restoreSelectedModel();
      ref.read(conversationsRefreshProvider.notifier).state++;
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
      toolbarHeight: 62,
      leading: IconButton(
        icon: Icon(Icons.menu_rounded, color: AppTheme.textPrimary),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: const ModelSelectorButton(),
      actions: [
        NewChatButton(onPressed: _startNewChat),
        SizedBox(width: 12),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppTheme.border),
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WelcomeHeader(),
          SizedBox(height: 28),
          _QuickStartGrid(onTap: _startWithPrompt),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border(top: BorderSide(color: AppTheme.border)),
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
              ),
              child: Row(
                children: [
                  SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      cursorColor: AppTheme.accent,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Message',
                        hintStyle: TextStyle(color: AppTheme.textTertiary),
                        filled: false,
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
                  SizedBox(width: 8),
                ],
              ),
            ),
          ),
          SizedBox(width: 10),
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
                color: _hasText ? AppTheme.onAccent : AppTheme.textTertiary,
              ),
              onPressed: _hasText ? _sendMessage : null,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startNewChat() async {
    await ref.read(conversationsRepositoryProvider).removeEmptyConversations();
    ref.read(conversationsRefreshProvider.notifier).state++;
    _inputController.clear();
    if (mounted) setState(() => _hasText = false);
  }

  Future<void> _restoreSelectedModel() async {
    final selectedModelId = ref.read(storageServiceProvider).selectedModelId;
    if (selectedModelId == null || selectedModelId.isEmpty) return;

    final model = ref.read(modelsRepositoryProvider).getModelById(
          selectedModelId,
        );
    if (model == null ||
        model.status != ModelStatus.downloaded ||
        model.localPath == null) {
      await ref.read(storageServiceProvider).clearSelectedModel();
      ref.read(activeModelProvider.notifier).state = null;
      await ref.read(inferenceServiceProvider).unloadModel();
      return;
    }

    ref.read(activeModelProvider.notifier).state = model;
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
    final systemPrompt = ref.read(storageServiceProvider).getSetting<String>(
          HiveConstants.activeSystemPromptText,
          defaultValue: '',
        );
    final convo = await repo.createConversation(
      modelId: model.id,
      modelName: model.name,
      systemPrompt: systemPrompt.trim().isEmpty ? null : systemPrompt.trim(),
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
        title: Text('No Model Selected'),
        content: Text(
          'Please download and select an AI model to start chatting.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/models');
            },
            child: Text('Browse Models'),
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
          'Good ${_greeting()}',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w400,
              ),
        ),
        SizedBox(height: 6),
        Text(
          'How can I help today?',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
        ),
      ],
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
}

class _QuickStartGrid extends StatelessWidget {
  final Function(String) onTap;
  const _QuickStartGrid({required this.onTap});

  static const _prompts = [
    (
      'Summarize a topic',
      Icons.article_outlined,
      'Summarize the key concepts of '
    ),
    ('Write code', Icons.code_rounded, 'Write a function that '),
    ('Explain something', Icons.lightbulb_outline_rounded, 'Explain how '),
    ('Brainstorm ideas', Icons.auto_awesome_outlined, 'Give me 10 ideas for '),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK START',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTheme.textTertiary,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 12),
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
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    Icon(p.$2, size: 15, color: AppTheme.accent),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p.$1,
                        style: TextStyle(
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

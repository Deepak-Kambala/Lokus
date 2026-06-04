import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../services/inference_service.dart';
import '../../../conversations/providers/conversations_provider.dart';
import '../../../chat/domain/entities/chat_message.dart';
import '../../../models/providers/models_provider.dart';
import '../../domain/entities/conversation.dart';
import '../../../home/widgets/conversation_drawer.dart';
import '../../../home/widgets/model_selector_button.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String? modelId;
  final String? initialMessage;

  const ChatScreen({
    super.key,
    required this.conversationId,
    this.modelId,
    this.initialMessage,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scaffoldKey  = GlobalKey<ScaffoldState>();
  final _inputCtrl    = TextEditingController();
  final _scrollCtrl   = ScrollController();

  bool _hasText     = false;
  bool _isGenerating = false;
  bool _isLoadingModel = false;
  String? _modelLoadError;

  StreamSubscription? _streamSub;

  @override
  void initState() {
    super.initState();
    _inputCtrl.addListener(() {
      final has = _inputCtrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    final initial = widget.initialMessage?.trim();
    if (initial != null && initial.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _inputCtrl.text = initial;
        _sendMessage();
      });
    }
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Model loading ──────────────────────────────────────────────────────────

  Future<bool> _ensureModelLoaded() async {
    final inference = ref.read(inferenceServiceProvider);
    final model     = ref.read(activeModelProvider);

    if (model == null) {
      _showSnack('No model selected. Pick one from the model manager.');
      return false;
    }
    if (model.localPath == null) {
      _showSnack('Model not downloaded yet. Download it from Browse Models.');
      return false;
    }

    // Already loaded
    if (inference.isModelLoaded && inference.loadedModel?.id == model.id) {
      return true;
    }

    setState(() {
      _isLoadingModel = true;
      _modelLoadError = null;
    });

    final ok = await inference.loadModel(model);

    setState(() => _isLoadingModel = false);

    if (!ok) {
      setState(() => _modelLoadError =
          'Failed to load ${model.name}.\nThe GGUF file may be corrupt — try re-downloading.');
      return false;
    }
    return true;
  }

  // ── Send / generate ────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _isGenerating) return;

    final ready = await _ensureModelLoaded();
    if (!ready) return;

    _inputCtrl.clear();
    setState(() { _hasText = false; _isGenerating = true; });

    // Persist user message
    final userMsg = ChatMessage(
      id: const Uuid().v4(),
      conversationId: widget.conversationId,
      role: MessageRole.user,
      content: text,
      timestamp: DateTime.now(),
    );
    await ref.read(messagesProvider(widget.conversationId).notifier)
        .addMessage(userMsg);
    _scrollToBottom();

    // Add empty assistant bubble for streaming
    final assistantId  = const Uuid().v4();
    final assistantMsg = ChatMessage(
      id: assistantId,
      conversationId: widget.conversationId,
      role: MessageRole.assistant,
      content: '',
      timestamp: DateTime.now(),
      isStreaming: true,
    );
    await ref.read(messagesProvider(widget.conversationId).notifier)
        .addMessage(assistantMsg);

    // Fetch conversation system prompt if any
    final convo = ref.read(conversationsRepositoryProvider)
        .getById(widget.conversationId);

    final history = ref.read(messagesProvider(widget.conversationId));

    final inference = ref.read(inferenceServiceProvider);
    final stream    = inference.generateStream(
      history: history
          .where((m) =>
              m.id != userMsg.id &&
              !m.isStreaming &&
              m.content.isNotEmpty)
          .toList(),
      userMessage: text,
      systemPrompt: convo?.systemPrompt,
    );

    String accumulated = '';
    final startTime = DateTime.now();

    _streamSub = stream.listen(
      (token) {
        accumulated += token;
        ref.read(messagesProvider(widget.conversationId).notifier)
            .updateLastMessage(assistantMsg.copyWith(
          content: accumulated,
          isStreaming: true,
        ));
        _scrollToBottom();
      },
      onDone: () async {
        final elapsed = DateTime.now()
            .difference(startTime).inMilliseconds / 1000;
        final tokenCount = accumulated.split(' ').length;
        final tps = elapsed > 0 ? tokenCount / elapsed : 0.0;

        await ref.read(messagesProvider(widget.conversationId).notifier)
            .updateLastMessage(assistantMsg.copyWith(
          content: accumulated,
          isStreaming: false,
          tokenCount: tokenCount,
          generationSeconds: elapsed,
          tokensPerSecond: tps,
        ));
        if (mounted) setState(() => _isGenerating = false);
        _scrollToBottom();
      },
      onError: (e) async {
        await ref.read(messagesProvider(widget.conversationId).notifier)
            .updateLastMessage(assistantMsg.copyWith(
          content: 'Error: $e',
          isStreaming: false,
          isError: true,
        ));
        if (mounted) setState(() => _isGenerating = false);
      },
      cancelOnError: true,
    );
  }

  void _stopGeneration() {
    _streamSub?.cancel();
    ref.read(inferenceServiceProvider).stopGeneration();
    setState(() => _isGenerating = false);
  }

  // ── UI helpers ─────────────────────────────────────────────────────────────

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider(widget.conversationId));
    final convo    = ref.watch(conversationsRepositoryProvider)
        .getById(widget.conversationId);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.background,
      drawer: const ConversationDrawer(),
      appBar: _buildAppBar(convo),
      body: Column(
        children: [
          // Model-loading banner
          if (_isLoadingModel) _LoadingModelBanner(),
          if (_modelLoadError != null)
            _ErrorBanner(
              message: _modelLoadError!,
              onDismiss: () => setState(() => _modelLoadError = null),
            ),
          Expanded(
            child: messages.isEmpty
                ? _EmptyChat(modelName: convo?.modelName ?? '')
                : _MessageList(
                    messages: messages,
                    scrollController: _scrollCtrl,
                    conversationId: widget.conversationId,
                  ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(Conversation? convo) {
    final activeModel = ref.watch(activeModelProvider);
    return AppBar(
      backgroundColor: AppTheme.background,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded, color: AppTheme.textPrimary),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: Column(
        children: [
          const ModelSelectorButton(),
          if (activeModel != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${activeModel.sizeString} · ${activeModel.parameterString}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textTertiary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, color: AppTheme.textSecondary),
          onPressed: _newChat,
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppTheme.border),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      padding: EdgeInsets.only(
        left: 12, right: 12, top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      enabled: !_isGenerating && !_isLoadingModel,
                      style: const TextStyle(
                          fontSize: 14, color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        hintStyle: TextStyle(color: AppTheme.textTertiary),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                        isDense: true,
                      ),
                      maxLines: 6,
                      minLines: 1,
                      textInputAction: TextInputAction.newline,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 6, bottom: 6),
                    child: IconButton(
                      icon: const Icon(Icons.mic_none_rounded,
                          size: 18, color: AppTheme.textTertiary),
                      onPressed: () {},
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _isLoadingModel
                  ? AppTheme.surfaceHighlight
                  : _isGenerating
                      ? AppTheme.surfaceHighlight
                      : _hasText
                          ? AppTheme.accent
                          : AppTheme.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: _isLoadingModel
                    ? AppTheme.border
                    : _isGenerating
                        ? AppTheme.accent
                        : _hasText
                            ? AppTheme.accent
                            : AppTheme.border,
              ),
            ),
            child: _isLoadingModel
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.accent),
                  )
                : _isGenerating
                    ? IconButton(
                        icon: const Icon(Icons.stop_rounded,
                            size: 16, color: AppTheme.accent),
                        onPressed: _stopGeneration,
                        padding: EdgeInsets.zero,
                      )
                    : IconButton(
                        icon: Icon(
                          Icons.arrow_upward_rounded,
                          size: 16,
                          color: _hasText
                              ? Colors.black
                              : AppTheme.textTertiary,
                        ),
                        onPressed: _hasText ? _sendMessage : null,
                        padding: EdgeInsets.zero,
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _newChat() async {
    final model = ref.read(activeModelProvider);
    if (model == null) return;

    final repo  = ref.read(conversationsRepositoryProvider);
    final convo = await repo.createConversation(
      modelId: model.id,
      modelName: model.name,
    );
    ref.read(conversationsRefreshProvider.notifier).state++;

    if (mounted) context.pushReplacement('/chat/${convo.id}');
  }
}

// ── Banners ────────────────────────────────────────────────────────────────────

class _LoadingModelBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppTheme.accentSurface,
      child: const Row(
        children: [
          SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2, color: AppTheme.accentLight),
          ),
          SizedBox(width: 10),
          Text(
            'Loading model into memory…',
            style: TextStyle(
              fontSize: 12, color: AppTheme.accentLight,
              fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppTheme.error.withOpacity(0.1),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: AppTheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12, color: AppTheme.error),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close_rounded,
                size: 16, color: AppTheme.error),
          ),
        ],
      ),
    );
  }
}

// ── Message List ───────────────────────────────────────────────────────────────

class _MessageList extends StatelessWidget {
  final List<ChatMessage> messages;
  final ScrollController scrollController;
  final String conversationId;

  const _MessageList({
    required this.messages,
    required this.scrollController,
    required this.conversationId,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: messages.length,
      itemBuilder: (context, index) =>
          _MessageBubble(message: messages[index]),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Role label + avatar
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isUser)
                Container(
                  width: 24, height: 24,
                  margin: const EdgeInsets.only(right: 8, bottom: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentSurface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      size: 12, color: AppTheme.accent),
                ),
              Text(
                isUser ? 'You' : 'Assistant',
                style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary),
              ),
              if (isUser)
                Container(
                  width: 24, height: 24,
                  margin: const EdgeInsets.only(left: 8, bottom: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceHighlight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.person_outline_rounded,
                      size: 12, color: AppTheme.textSecondary),
                ),
            ],
          ),
          // Bubble
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85),
            margin: EdgeInsets.only(
              left: isUser ? 40 : 0,
              right: isUser ? 0 : 40,
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isUser
                  ? AppTheme.userBubble
                  : AppTheme.assistantBubble,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 16),
              ),
              border: Border.all(
                color: isUser
                    ? AppTheme.accentDim.withOpacity(0.5)
                    : AppTheme.border,
              ),
            ),
            child: message.isStreaming && message.content.isEmpty
                ? _TypingIndicator()
                : _BubbleContent(message: message),
          ),
          // Actions row for assistant
          if (!isUser && !message.isStreaming &&
              message.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _MessageActions(message: message),
            ),
        ],
      ),
    );
  }
}

class _BubbleContent extends StatelessWidget {
  final ChatMessage message;
  const _BubbleContent({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isError) {
      return Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 14, color: AppTheme.error),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message.content,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.error),
            ),
          ),
        ],
      );
    }

    if (message.role == MessageRole.user) {
      return Text(
        message.content,
        style: const TextStyle(
            fontSize: 14, color: AppTheme.textPrimary, height: 1.5),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarkdownBody(
          data: message.content,
          styleSheet: _mdStyle(),
          selectable: true,
        ),
        if (message.isStreaming)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _CursorBlink(),
          ),
        if (!message.isStreaming &&
            (message.tokenCount ?? 0) > 0)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _TokenStats(message: message),
          ),
      ],
    );
  }

  MarkdownStyleSheet _mdStyle() => MarkdownStyleSheet(
    p: const TextStyle(
        fontSize: 14, color: AppTheme.textPrimary,
        height: 1.55, fontFamily: 'Inter'),
    code: const TextStyle(
        fontSize: 12, color: AppTheme.accentLight,
        backgroundColor: AppTheme.accentSurface,
        fontFamily: 'monospace'),
    codeblockDecoration: BoxDecoration(
      color: AppTheme.surfaceHighlight,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppTheme.border),
    ),
    h1: const TextStyle(
        fontSize: 18, fontWeight: FontWeight.w700,
        color: AppTheme.textPrimary, fontFamily: 'Inter'),
    h2: const TextStyle(
        fontSize: 16, fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary, fontFamily: 'Inter'),
    h3: const TextStyle(
        fontSize: 15, fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary, fontFamily: 'Inter'),
    strong: const TextStyle(
        fontWeight: FontWeight.w700,
        color: AppTheme.textPrimary, fontFamily: 'Inter'),
    listBullet: const TextStyle(color: AppTheme.accent),
  );
}

class _TokenStats extends StatelessWidget {
  final ChatMessage message;
  const _TokenStats({required this.message});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (message.tokenCount != null) parts.add('${message.tokenCount} tokens');
    if (message.generationSeconds != null)
      parts.add('${message.generationSeconds!.toStringAsFixed(1)}s');
    if (message.tokensPerSecond != null)
      parts.add('${message.tokensPerSecond!.toStringAsFixed(1)} tok/s');

    return Text(
      parts.join(' · '),
      style: const TextStyle(
          fontSize: 10, color: AppTheme.textTertiary,
          fontFamily: 'monospace'),
    );
  }
}

class _MessageActions extends StatelessWidget {
  final ChatMessage message;
  const _MessageActions({required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionBtn(
          icon: Icons.copy_outlined,
          tooltip: 'Copy',
          onTap: () {
            Clipboard.setData(ClipboardData(text: message.content));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Copied'),
              duration: Duration(seconds: 1),
            ));
          },
        ),
        const SizedBox(width: 4),
        _ActionBtn(
            icon: Icons.thumb_up_outlined,
            tooltip: 'Good response',
            onTap: () {}),
        const SizedBox(width: 4),
        _ActionBtn(
            icon: Icons.thumb_down_outlined,
            tooltip: 'Bad response',
            onTap: () {}),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.border),
          ),
          child: Icon(icon, size: 13, color: AppTheme.textSecondary),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final delay = i * 0.3;
          final t = (_ctrl.value - delay).clamp(0.0, 1.0);
          final opacity = 0.3 +
              0.7 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 6, height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.accent.withOpacity(opacity),
            ),
          );
        }),
      ),
    );
  }
}

class _CursorBlink extends StatefulWidget {
  @override
  State<_CursorBlink> createState() => _CursorBlinkState();
}

class _CursorBlinkState extends State<_CursorBlink>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _ctrl,
    child: Container(width: 2, height: 14, color: AppTheme.accent),
  );
}

class _EmptyChat extends StatelessWidget {
  final String modelName;
  const _EmptyChat({required this.modelName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: AppTheme.accentSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.accentDim),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: AppTheme.accent, size: 28),
            ),
            const SizedBox(height: 20),
            Text(
              modelName.isNotEmpty ? modelName : 'AI Assistant',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Model loads on your first message.',
              style: TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

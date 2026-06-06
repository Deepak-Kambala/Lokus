import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../core/constants/hive_constants.dart';
import '../../../../services/inference_service.dart';
import '../../../../services/storage_service.dart';
import '../../../../services/web_grounding_service.dart';
import '../../../conversations/providers/conversations_provider.dart';
import '../../../chat/domain/entities/chat_message.dart';
import '../../../models/data/repositories/models_repository.dart';
import '../../../models/domain/entities/ai_model.dart';
import '../../../models/providers/models_provider.dart';
import '../../domain/entities/conversation.dart';
import '../../../home/widgets/conversation_drawer.dart';
import '../../../home/widgets/model_selector_button.dart';
import '../../../home/widgets/new_chat_button.dart';

final _webGroundingServiceProvider = Provider<WebGroundingService>((ref) {
  return WebGroundingService();
});

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
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  bool _hasText = false;
  bool _isGenerating = false;
  bool _isSending = false;
  bool _isStopping = false;
  bool _isLoadingModel = false;
  bool _autoScrollWithStream = true;
  DateTime? _lastStreamScrollAt;
  String? _modelLoadError;

  StreamSubscription? _streamSub;
  Future<void>? _stopFuture;
  int _generationRunId = 0;
  String? _activeAssistantId;
  String _activeAssistantContent = '';
  static const String _interruptedMessage = 'You interrupted the response.';

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
    ref.read(inferenceServiceProvider).stopGeneration();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Model loading ──────────────────────────────────────────────────────────

  Future<bool> _ensureModelLoaded(AiModel model) async {
    final inference = ref.read(inferenceServiceProvider);

    if (model.localPath == null) {
      _showSnack('${model.name} is not downloaded. Download it again.');
      return false;
    }
    if (model.sizeGb > 1.6) {
      setState(() {
        _modelLoadError =
            '${model.name} is too large for stable on-device chat here. Use a lighter model such as Qwen3-0.6B, gemma-3-1b-it, or Llama-3.2-1B-Instruct.';
      });
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

    if (!mounted) return false;
    setState(() => _isLoadingModel = false);

    if (!ok) {
      final detail = inference.lastErrorMessage ??
          'The GGUF file may be corrupt - try re-downloading.';
      setState(
          () => _modelLoadError = 'Failed to load ${model.name}.\n$detail');
      return false;
    }
    return true;
  }

  // ── Send / generate ────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _isGenerating || _isSending) return;

    _inputCtrl.clear();
    setState(() {
      _hasText = false;
      _isSending = true;
    });

    var restoreInputOnFailure = true;
    Future<void> restoreInput() async {
      if (!restoreInputOnFailure || !mounted) return;
      _inputCtrl.text = text;
      _inputCtrl.selection = TextSelection.collapsed(offset: text.length);
      setState(() {
        _hasText = text.trim().isNotEmpty;
        _isSending = false;
      });
    }

    await _waitForStopCleanup();
    if (!mounted || _isGenerating) {
      await restoreInput();
      return;
    }

    final convo = ref
        .read(conversationsRepositoryProvider)
        .getById(widget.conversationId);
    if (convo == null) {
      _showSnack('Chat not found. Start a new chat.');
      await restoreInput();
      return;
    }

    final activeModel = ref.read(activeModelProvider);
    if (activeModel != null && activeModel.id != convo.modelId) {
      restoreInputOnFailure = false;
      if (mounted) setState(() => _isSending = false);
      await _openNewChatForModel(activeModel, text);
      return;
    }

    final model =
        ref.read(modelsRepositoryProvider).getModelById(convo.modelId);
    if (model == null ||
        model.status != ModelStatus.downloaded ||
        model.localPath == null) {
      _showSnack('${convo.modelName} is missing. Download it again.');
      ref.read(modelsRefreshProvider.notifier).state++;
      await restoreInput();
      return;
    }

    final ready = await _ensureModelLoaded(model);
    if (!ready) {
      await restoreInput();
      return;
    }

    setState(() {
      _isSending = false;
      _isGenerating = true;
      _autoScrollWithStream = true;
    });
    restoreInputOnFailure = false;
    final runId = ++_generationRunId;
    _activeAssistantContent = '';

    final assistantId = const Uuid().v4();
    final assistantMsg = ChatMessage(
      id: assistantId,
      conversationId: widget.conversationId,
      role: MessageRole.assistant,
      content: '',
      timestamp: DateTime.now(),
      isStreaming: true,
    );
    _activeAssistantId = assistantId;

    // Persist user message
    final userMsg = ChatMessage(
      id: const Uuid().v4(),
      conversationId: widget.conversationId,
      role: MessageRole.user,
      content: text,
      timestamp: DateTime.now(),
    );
    await ref
        .read(messagesProvider(widget.conversationId).notifier)
        .addMessage(userMsg);
    if (!_isRunActive(runId)) {
      await _addInterruptedMessageIfNeeded(assistantMsg);
      return;
    }
    _scrollToBottom(force: true);

    await _waitForStopCleanup();
    if (!_isRunActive(runId)) {
      await _addInterruptedMessageIfNeeded(assistantMsg);
      return;
    }

    // Add empty assistant bubble for streaming
    await ref
        .read(messagesProvider(widget.conversationId).notifier)
        .addMessage(assistantMsg);
    if (!_isRunActive(runId)) {
      await _finalizeInterruptedMessage(assistantId, assistantMsg);
      return;
    }

    final history = ref.read(messagesProvider(widget.conversationId));
    final baseSystemPrompt = _systemPromptForLanguage(convo.systemPrompt);
    var systemPrompt = baseSystemPrompt;
    final grounding = await ref.read(_webGroundingServiceProvider).ground(text);
    if (!_isRunActive(runId)) {
      await _finalizeInterruptedMessage(assistantId, assistantMsg);
      return;
    }
    if (grounding != null) {
      if (!grounding.hasSources) {
        await ref
            .read(messagesProvider(widget.conversationId).notifier)
            .updateMessage(assistantMsg.copyWith(
              content:
                  'I could not verify this with current web sources right now, so I should not guess.',
              isStreaming: false,
              isError: false,
            ));
        _activeAssistantId = null;
        _activeAssistantContent = '';
        if (mounted) setState(() => _isGenerating = false);
        _scrollToBottom(force: true);
        return;
      }
      systemPrompt = _systemPromptWithGrounding(baseSystemPrompt, grounding);
    }

    final inference = ref.read(inferenceServiceProvider);
    final stream = inference.generateStream(
      history: _compactHistoryForPrompt(history, userMsg.id, text),
      userMessage: text,
      systemPrompt: systemPrompt,
    );

    String accumulated = '';
    final startTime = DateTime.now();

    _streamSub = stream.listen(
      (token) {
        if (!_isCurrentGeneration(runId, assistantId)) return;
        accumulated += token;
        _activeAssistantContent = accumulated;
        ref
            .read(messagesProvider(widget.conversationId).notifier)
            .updateMessage(assistantMsg.copyWith(
              content: accumulated,
              isStreaming: true,
            ));
        _scrollToBottom();
      },
      onDone: () async {
        if (!_isCurrentGeneration(runId, assistantId)) return;
        if (accumulated.trim().isEmpty) {
          await ref
              .read(messagesProvider(widget.conversationId).notifier)
              .updateMessage(assistantMsg.copyWith(
                content: 'The model returned no text. Please try again.',
                isStreaming: false,
                isError: true,
              ));
          _activeAssistantId = null;
          _activeAssistantContent = '';
          if (mounted) setState(() => _isGenerating = false);
          return;
        }

        final elapsed =
            DateTime.now().difference(startTime).inMilliseconds / 1000;
        final tokenCount = accumulated.split(' ').length;
        final tps = elapsed > 0 ? tokenCount / elapsed : 0.0;

        await ref
            .read(messagesProvider(widget.conversationId).notifier)
            .updateMessage(assistantMsg.copyWith(
              content: accumulated,
              isStreaming: false,
              tokenCount: tokenCount,
              generationSeconds: elapsed,
              tokensPerSecond: tps,
            ));
        _activeAssistantId = null;
        _activeAssistantContent = '';
        if (mounted) setState(() => _isGenerating = false);
        _scrollToBottom(force: true);
      },
      onError: (e) async {
        if (!_isCurrentGeneration(runId, assistantId)) return;
        await ref
            .read(messagesProvider(widget.conversationId).notifier)
            .updateMessage(assistantMsg.copyWith(
              content: _friendlyGenerationError(e),
              isStreaming: false,
              isError: true,
            ));
        _activeAssistantId = null;
        _activeAssistantContent = '';
        if (mounted) setState(() => _isGenerating = false);
      },
      cancelOnError: true,
    );
  }

  bool _isCurrentGeneration(int runId, String assistantId) {
    return _isRunActive(runId) && _activeAssistantId == assistantId;
  }

  bool _isRunActive(int runId) {
    return mounted && _generationRunId == runId && _isGenerating;
  }

  Future<void> _waitForStopCleanup() async {
    final stopFuture = _stopFuture;
    if (stopFuture == null) return;
    await stopFuture;
  }

  Future<void> _stopGeneration() async {
    if (!_isGenerating || _isStopping) {
      return;
    }
    await _stopGenerationInternal();
  }

  Future<void> _stopGenerationInternal() async {
    if (!_isGenerating || _isStopping) return;

    final assistantId = _activeAssistantId;
    final content = _activeAssistantContent;
    _generationRunId++;
    _activeAssistantId = null;
    _activeAssistantContent = '';
    final streamSub = _streamSub;
    _streamSub = null;

    if (mounted) {
      setState(() {
        _isGenerating = false;
        _isStopping = true;
      });
    }

    late Future<void> trackedCleanup;
    final cleanup = Future<void>(() async {
      await ref.read(inferenceServiceProvider).stopGeneration();
      await streamSub?.cancel();
    });
    trackedCleanup = cleanup.catchError((_) {}).whenComplete(() {
      if (identical(_stopFuture, trackedCleanup)) {
        _stopFuture = null;
      }
      if (mounted) {
        setState(() => _isStopping = false);
      }
    });
    _stopFuture = trackedCleanup;

    if (assistantId == null) return;

    final notifier = ref.read(messagesProvider(widget.conversationId).notifier);
    ChatMessage? message;
    for (final existing in ref.read(messagesProvider(widget.conversationId))) {
      if (existing.id == assistantId) {
        message = existing;
        break;
      }
    }

    if (message == null) return;
    if (content.trim().isEmpty) {
      await notifier.updateMessage(message.copyWith(
        content: _interruptedMessage,
        isStreaming: false,
        isError: false,
      ));
    } else {
      await notifier.updateMessage(message.copyWith(
        content: content,
        isStreaming: false,
      ));
    }
  }

  Future<void> _addInterruptedMessageIfNeeded(ChatMessage assistantMsg) async {
    final exists = ref
        .read(messagesProvider(widget.conversationId))
        .any((message) => message.id == assistantMsg.id);
    if (exists) {
      await _finalizeInterruptedMessage(assistantMsg.id, assistantMsg);
      return;
    }
    await ref.read(messagesProvider(widget.conversationId).notifier).addMessage(
          assistantMsg.copyWith(
            content: _interruptedMessage,
            isStreaming: false,
            isError: false,
          ),
        );
  }

  Future<void> _finalizeInterruptedMessage(
    String assistantId,
    ChatMessage fallback,
  ) async {
    final notifier = ref.read(messagesProvider(widget.conversationId).notifier);
    ChatMessage? message;
    for (final existing in ref.read(messagesProvider(widget.conversationId))) {
      if (existing.id == assistantId) {
        message = existing;
        break;
      }
    }
    if (message == null) {
      await notifier.addMessage(fallback.copyWith(
        content: _interruptedMessage,
        isStreaming: false,
        isError: false,
      ));
      return;
    }
    await notifier.updateMessage(message.copyWith(
      content: message.content.trim().isEmpty
          ? _interruptedMessage
          : message.content,
      isStreaming: false,
      isError: false,
    ));
  }

  // ── UI helpers ─────────────────────────────────────────────────────────────

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        final distanceFromBottom =
            _scrollCtrl.position.maxScrollExtent - _scrollCtrl.offset;
        if (!force) {
          if (!_autoScrollWithStream) return;
          if (distanceFromBottom > 120) {
            _autoScrollWithStream = false;
            return;
          }
          final now = DateTime.now();
          final last = _lastStreamScrollAt;
          if (last != null && now.difference(last).inMilliseconds < 90) {
            return;
          }
          _lastStreamScrollAt = now;
        } else {
          _autoScrollWithStream = true;
        }
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: Duration(milliseconds: force ? 240 : 140),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _handleMessageScroll(ScrollNotification notification) {
    if (!_isGenerating) return false;

    final distanceFromBottom =
        notification.metrics.maxScrollExtent - notification.metrics.pixels;
    if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      _autoScrollWithStream = distanceFromBottom < 48;
    } else if (notification is UserScrollNotification &&
        notification.direction == ScrollDirection.idle &&
        distanceFromBottom < 80) {
      _autoScrollWithStream = true;
    }

    return false;
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openNewChatForModel(
      AiModel model, String initialMessage) async {
    final repo = ref.read(conversationsRepositoryProvider);
    await repo.removeEmptyConversations();
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

    if (!mounted) return;
    _inputCtrl.clear();
    setState(() => _hasText = false);
    context.pushReplacement(
      '/chat/${convo.id}',
      extra: initialMessage.isNotEmpty ? initialMessage : null,
    );
  }

  List<ChatMessage> _compactHistoryForPrompt(
    List<ChatMessage> history,
    String currentUserMessageId,
    String currentUserMessage,
  ) {
    const maxMessages = 16;
    const maxTotalChars = 5200;
    const maxCharsPerMessage = 900;

    final eligible = history
        .where((m) =>
            m.id != currentUserMessageId &&
            !m.isStreaming &&
            !m.isError &&
            m.content.trim().isNotEmpty)
        .toList();

    if (!_shouldUsePriorContext(currentUserMessage, eligible)) {
      return const [];
    }

    final selected = <ChatMessage>[];
    var usedChars = 0;

    for (final message in eligible.reversed) {
      if (selected.length >= maxMessages || usedChars >= maxTotalChars) break;

      var content = message.content.trim();
      if (content.length > maxCharsPerMessage) {
        content = content.substring(content.length - maxCharsPerMessage);
      }

      final remaining = maxTotalChars - usedChars;
      if (content.length > remaining) {
        content = content.substring(content.length - remaining);
      }

      selected.add(message.copyWith(content: content));
      usedChars += content.length;
    }

    return selected.reversed.toList();
  }

  bool _shouldUsePriorContext(
    String currentUserMessage,
    List<ChatMessage> history,
  ) {
    if (history.isEmpty) return false;

    final text = currentUserMessage.trim();
    final lower = text.toLowerCase();

    final explicitReset = RegExp(
      r'\b(new topic|different topic|different question|unrelated|ignore (the )?(previous|above|earlier)|forget (the )?(previous|above|earlier)|start over|fresh question)\b',
      caseSensitive: false,
    );
    if (explicitReset.hasMatch(lower)) return false;

    final explicitReference = RegExp(
      r'\b(this|that|these|those|it|its|they|them|above|previous|earlier|same|continue|explain more|expand|summarize|rewrite|make it|change it|fix it|why|how so|what about)\b',
      caseSensitive: false,
    );
    if (explicitReference.hasMatch(lower) && _wordCount(text) <= 18) {
      return true;
    }

    final currentKeywords = _topicKeywords(text);
    if (currentKeywords.length < 2) {
      return _wordCount(text) <= 8 && explicitReference.hasMatch(lower);
    }

    final recentUserMessages = history
        .where((m) => m.role == MessageRole.user)
        .toList(growable: false)
        .reversed
        .take(4);

    var bestOverlap = 0.0;
    for (final message in recentUserMessages) {
      final previousKeywords = _topicKeywords(message.content);
      if (previousKeywords.isEmpty) continue;
      final overlap = _keywordOverlap(currentKeywords, previousKeywords);
      if (overlap > bestOverlap) bestOverlap = overlap;
    }

    if (bestOverlap >= 0.20) return true;

    final recentAssistantMessages = history
        .where((m) => m.role == MessageRole.assistant)
        .toList(growable: false)
        .reversed
        .take(2);
    for (final message in recentAssistantMessages) {
      final previousKeywords = _topicKeywords(message.content);
      if (_keywordOverlap(currentKeywords, previousKeywords) >= 0.24) {
        return true;
      }
    }

    return false;
  }

  Set<String> _topicKeywords(String text) {
    final normalized = text.toLowerCase();
    final matches = RegExp(r"[a-z0-9][a-z0-9_+\-.'/#]{2,}").allMatches(
      normalized,
    );
    final keywords = <String>{};
    for (final match in matches) {
      final token = match.group(0);
      if (token == null) continue;
      final cleaned = token.replaceAll(RegExp(r"^['.]+|['.]+$"), '');
      if (cleaned.length < 3 || _contextStopWords.contains(cleaned)) continue;
      keywords.add(cleaned);
    }
    return keywords;
  }

  double _keywordOverlap(Set<String> current, Set<String> previous) {
    if (current.isEmpty || previous.isEmpty) return 0.0;
    final intersection = current.intersection(previous).length;
    return intersection / current.length;
  }

  int _wordCount(String text) {
    return RegExp(r'\S+').allMatches(text.trim()).length;
  }

  static const Set<String> _contextStopWords = {
    'about',
    'after',
    'again',
    'also',
    'answer',
    'because',
    'before',
    'best',
    'can',
    'chat',
    'code',
    'could',
    'create',
    'current',
    'does',
    'explain',
    'from',
    'give',
    'help',
    'how',
    'into',
    'make',
    'need',
    'please',
    'question',
    'request',
    'same',
    'show',
    'tell',
    'that',
    'the',
    'their',
    'them',
    'then',
    'there',
    'these',
    'thing',
    'this',
    'those',
    'use',
    'using',
    'want',
    'what',
    'when',
    'where',
    'which',
    'with',
    'would',
    'write',
    'your',
  };

  String _friendlyGenerationError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    if (text.contains('The model returned no text')) {
      return 'The model returned no text. Please try again.';
    }
    if (text.isEmpty) {
      return 'Generation failed. Try a smaller model or re-download the file.';
    }
    return 'Error: $text';
  }

  String? _systemPromptForLanguage(String? conversationPrompt) {
    final language = ref.read(storageServiceProvider).getSetting<String>(
          HiveConstants.appLanguage,
          defaultValue: 'English (United States)',
        );
    final parts = <String>[];
    final base = conversationPrompt?.trim();
    if (base != null && base.isNotEmpty) {
      parts.add(base);
    }
    if (language == 'Auto') {
      parts.add(
        'Reply in English. Answer directly. For writing or creative requests, produce the requested content immediately with sensible defaults instead of asking what to write about. Do not reveal hidden reasoning, chain-of-thought, internal thoughts, thinking notes, or <think> sections.',
      );
    } else {
      parts.add(
        'Reply in $language. Answer directly. For writing or creative requests, produce the requested content immediately with sensible defaults instead of asking what to write about. Do not reveal hidden reasoning, chain-of-thought, internal thoughts, thinking notes, or <think> sections.',
      );
    }
    return parts.join('\n\n');
  }

  String _systemPromptWithGrounding(
    String? basePrompt,
    WebGroundingResult grounding,
  ) {
    final parts = <String>[
      if (basePrompt != null && basePrompt.trim().isNotEmpty) basePrompt.trim(),
      'Current web source context is available for this answer. Use it for factual claims. Answer from the sources when they support the answer, mention uncertainty when they do not, and do not make up unsupported details. Include short source names in the answer when useful.',
      grounding.toPromptContext(),
    ];
    return parts.join('\n\n');
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider(widget.conversationId));
    final convo = ref
        .watch(conversationsRepositoryProvider)
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
                : NotificationListener<ScrollNotification>(
                    onNotification: _handleMessageScroll,
                    child: _MessageList(
                      messages: messages,
                      scrollController: _scrollCtrl,
                      conversationId: widget.conversationId,
                    ),
                  ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(Conversation? convo) {
    return AppBar(
      backgroundColor: AppTheme.background,
      toolbarHeight: 62,
      leading: IconButton(
        icon: Icon(Icons.menu_rounded, color: AppTheme.textPrimary),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: const ModelSelectorButton(),
      actions: [
        NewChatButton(onPressed: _newChat),
        SizedBox(width: 12),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppTheme.border),
      ),
    );
  }

  Widget _buildInputBar() {
    final canSend = _hasText && !_isSending && !_isLoadingModel;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _inputCtrl,
                enabled: !_isLoadingModel,
                cursorColor: AppTheme.accent,
                style: TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Ask anything',
                  hintStyle: TextStyle(color: AppTheme.textTertiary),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  isDense: true,
                ),
                maxLines: 6,
                minLines: 1,
                textInputAction: TextInputAction.newline,
              ),
            ),
          ),
          SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _isLoadingModel
                  ? AppTheme.surfaceHighlight
                  : _isGenerating
                      ? AppTheme.surfaceHighlight
                      : canSend
                          ? AppTheme.accent
                          : AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isLoadingModel
                    ? AppTheme.border
                    : _isGenerating
                        ? AppTheme.accent
                        : canSend
                            ? AppTheme.accent
                            : AppTheme.border,
              ),
            ),
            child: _isLoadingModel
                ? Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.accent),
                  )
                : _isGenerating
                    ? IconButton(
                        icon: Icon(Icons.stop_rounded,
                            size: 16, color: AppTheme.accent),
                        onPressed: () => _stopGeneration(),
                        padding: EdgeInsets.zero,
                      )
                    : IconButton(
                        icon: Icon(
                          Icons.arrow_upward_rounded,
                          size: 16,
                          color: canSend
                              ? AppTheme.onAccent
                              : AppTheme.textTertiary,
                        ),
                        onPressed: canSend ? _sendMessage : null,
                        padding: EdgeInsets.zero,
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _newChat() async {
    await ref.read(conversationsRepositoryProvider).removeEmptyConversations();
    ref.read(conversationsRefreshProvider.notifier).state++;

    if (mounted) context.go('/home');
  }
}

// ── Banners ────────────────────────────────────────────────────────────────────

class _LoadingModelBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppTheme.accentSurface,
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppTheme.accentLight),
          ),
          SizedBox(width: 10),
          Text(
            'Loading model into memory…',
            style: TextStyle(
                fontSize: 12,
                color: AppTheme.accentLight,
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
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppTheme.error.withOpacity(0.1),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 16, color: AppTheme.error),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: AppTheme.error),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close_rounded, size: 16, color: AppTheme.error),
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
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: messages.length,
      itemBuilder: (context, index) => _MessageBubble(message: messages[index]),
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
      padding: EdgeInsets.only(bottom: 20),
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
                  width: 24,
                  height: 24,
                  margin: EdgeInsets.only(right: 8, bottom: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentSurface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.auto_awesome_rounded,
                      size: 12, color: AppTheme.accent),
                ),
              Text(
                isUser ? 'You' : 'Assistant',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary),
              ),
              if (isUser)
                Container(
                  width: 24,
                  height: 24,
                  margin: EdgeInsets.only(left: 8, bottom: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceHighlight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.person_outline_rounded,
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
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isUser ? AppTheme.userBubble : AppTheme.assistantBubble,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
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
          if (!isUser && !message.isStreaming && message.content.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 6),
              child: _CopyMessageAction(message: message),
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
          Icon(Icons.warning_amber_rounded, size: 14, color: AppTheme.error),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              message.content,
              style: TextStyle(fontSize: 13, color: AppTheme.error),
            ),
          ),
        ],
      );
    }

    if (message.role == MessageRole.user) {
      return Text(
        message.content,
        style:
            TextStyle(fontSize: 14, color: AppTheme.textPrimary, height: 1.5),
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
            padding: EdgeInsets.only(top: 4),
            child: _CursorBlink(),
          ),
        if (!message.isStreaming && (message.tokenCount ?? 0) > 0)
          Padding(
            padding: EdgeInsets.only(top: 10),
            child: _TokenStats(message: message),
          ),
      ],
    );
  }

  MarkdownStyleSheet _mdStyle() => MarkdownStyleSheet(
        p: TextStyle(
            fontSize: 14,
            color: AppTheme.textPrimary,
            height: 1.55,
            fontFamily: 'Inter'),
        code: TextStyle(
            fontSize: 12,
            color: AppTheme.accentLight,
            backgroundColor: AppTheme.accentSurface,
            fontFamily: 'monospace'),
        codeblockDecoration: BoxDecoration(
          color: AppTheme.surfaceHighlight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        h1: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            fontFamily: 'Inter'),
        h2: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
            fontFamily: 'Inter'),
        h3: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
            fontFamily: 'Inter'),
        strong: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            fontFamily: 'Inter'),
        listBullet: TextStyle(color: AppTheme.accent),
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
      style: TextStyle(
          fontSize: 10, color: AppTheme.textTertiary, fontFamily: 'monospace'),
    );
  }
}

class _CopyMessageAction extends StatelessWidget {
  final ChatMessage message;
  const _CopyMessageAction({required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionBtn(
          icon: Icons.copy_outlined,
          tooltip: 'Copy',
          onTap: () {
            Clipboard.setData(ClipboardData(text: message.content));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Copied'),
              duration: Duration(seconds: 1),
            ));
          },
        ),
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
          padding: EdgeInsets.all(5),
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
          final opacity = 0.3 + 0.7 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
          return Container(
            margin: EdgeInsets.symmetric(horizontal: 2),
            width: 6,
            height: 6,
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
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.accentSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.accentDim),
              ),
              child: Icon(Icons.auto_awesome_rounded,
                  color: AppTheme.accent, size: 28),
            ),
            SizedBox(height: 20),
            Text(
              modelName.isNotEmpty ? modelName : 'AI Assistant',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Model loads on your first message.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

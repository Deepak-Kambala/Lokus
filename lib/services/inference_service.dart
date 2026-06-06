import 'dart:async';
import 'dart:io';

import 'package:flutter_llama/flutter_llama.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/app_log.dart';
import '../features/chat/domain/entities/chat_message.dart';
import '../features/models/domain/entities/ai_model.dart';

final inferenceServiceProvider = Provider<InferenceService>((ref) {
  return InferenceService();
});

class EmptyGenerationException implements Exception {
  final String message;
  const EmptyGenerationException([
    this.message = 'The model returned no text. Please try again.',
  ]);

  @override
  String toString() => message;
}

class InferenceService {
  static const int _defaultContextSize = 1024;
  static const double _answerTemperature = 0.25;
  static const double _fallbackTemperature = 0.05;

  final FlutterLlama _llama = FlutterLlama.instance;
  AiModel? _loadedModel;
  bool _isLoading = false;
  int _generationEpoch = 0;
  bool _stopRequested = false;
  int _loadedContextSize = _defaultContextSize;
  String? _lastErrorMessage;

  bool get isModelLoaded => _loadedModel != null;
  AiModel? get loadedModel => _loadedModel;
  bool get isLoading => _isLoading;
  String? get lastErrorMessage => _lastErrorMessage;

  Future<bool> loadModel(AiModel model) async {
    _lastErrorMessage = null;
    final path = model.localPath;
    if (path == null) {
      return _failLoad(
        model: model,
        path: null,
        fileSize: 0,
        message: 'Model path is missing. Download the model again.',
      );
    }

    final modelFile = File(path);
    var fileSize = 0;
    try {
      final exists = await modelFile.exists();
      fileSize = exists ? await modelFile.length() : 0;
      if (!exists || fileSize <= 1024 * 1024) {
        return _failLoad(
          model: model,
          path: path,
          fileSize: fileSize,
          message: exists
              ? 'Model file is too small or incomplete.'
              : 'Model file was not found.',
        );
      }

      final handle = await modelFile.open();
      await handle.close();
    } catch (e, stackTrace) {
      AppLog.error(
        _diagnosticMessage(
          '[Inference] Model file validation failed for ${model.id}',
          path: path,
          fileSize: fileSize,
          exception: e,
        ),
        e,
        stackTrace,
      );
      return _failLoad(
        model: model,
        path: path,
        fileSize: fileSize,
        message: 'Cannot read model file: $e',
      );
    }

    _isLoading = true;
    try {
      final threads = Platform.numberOfProcessors.clamp(2, 6).toInt();
      final primaryContext = _contextSizeFor(model);
      final configs = <LlamaConfig>[
        LlamaConfig(
          modelPath: path,
          nThreads: threads,
          nGpuLayers: model.sizeGb <= 1.2 ? 16 : 8,
          contextSize: primaryContext,
          batchSize: 256,
          useGpu: true,
        ),
        LlamaConfig(
          modelPath: path,
          nThreads: threads,
          nGpuLayers: 0,
          contextSize: primaryContext,
          batchSize: 256,
          useGpu: false,
        ),
        if (primaryContext > 1024)
          LlamaConfig(
            modelPath: path,
            nThreads: threads,
            nGpuLayers: 0,
            contextSize: 1024,
            batchSize: 192,
            useGpu: false,
          ),
        LlamaConfig(
          modelPath: path,
          nThreads: threads,
          nGpuLayers: 0,
          contextSize: 512,
          batchSize: 128,
          useGpu: false,
        ),
      ];

      for (var i = 0; i < configs.length; i++) {
        try {
          final ok = await _llama.loadModel(configs[i]);
          if (ok) {
            _loadedModel = model;
            _loadedContextSize = configs[i].contextSize;
            AppLog.debug('[Inference] Loaded: ${model.id}');
            return true;
          }
          AppLog.debug(
            _diagnosticMessage(
              '[Inference] Load attempt ${i + 1} failed for ${model.id}',
              path: path,
              fileSize: fileSize,
              exception: 'loadModel returned false',
            ),
          );
        } catch (e, stackTrace) {
          AppLog.error(
            _diagnosticMessage(
              '[Inference] Load attempt ${i + 1} failed for ${model.id}',
              path: path,
              fileSize: fileSize,
              exception: e,
            ),
            e,
            stackTrace,
          );
          _lastErrorMessage = 'Failed to load model: $e';
        }
        await _llama.unloadModel().catchError(
          (Object e, StackTrace stackTrace) {
            AppLog.error(
              _diagnosticMessage(
                '[Inference] Cleanup after load failure failed for ${model.id}',
                path: path,
                fileSize: fileSize,
                exception: e,
              ),
              e,
              stackTrace,
            );
          },
        );
      }
      _loadedModel = null;
      _lastErrorMessage ??= 'Failed to load model on this device.';
      return false;
    } catch (e, stackTrace) {
      AppLog.error(
        _diagnosticMessage(
          '[Inference] Load failed for ${model.id}',
          path: path,
          fileSize: fileSize,
          exception: e,
        ),
        e,
        stackTrace,
      );
      _loadedModel = null;
      _lastErrorMessage = 'Failed to load model: $e';
      return false;
    } finally {
      _isLoading = false;
    }
  }

  Stream<String> generateStream({
    required List<ChatMessage> history,
    required String userMessage,
    double temperature = _answerTemperature,
    int maxTokens = 512,
    String? systemPrompt,
  }) async* {
    if (_loadedModel == null) {
      throw Exception('No model loaded. Please select a downloaded model.');
    }

    final epoch = ++_generationEpoch;
    _stopRequested = false;
    final model = _loadedModel!;
    final modelFile = model.localPath == null ? null : File(model.localPath!);
    final fileSize = modelFile != null && await modelFile.exists()
        ? await modelFile.length()
        : 0;
    final prompt = _buildPrompt(
      history: history,
      userMessage: userMessage,
      systemPrompt: systemPrompt,
      model: model,
    );

    final primaryTemperature =
        temperature <= 0 ? _answerTemperature : temperature;
    final temperatures = [
      primaryTemperature.clamp(0.0, 0.45).toDouble(),
      _fallbackTemperature,
    ];
    for (var attempt = 0; attempt < temperatures.length; attempt++) {
      var raw = '';
      var emitted = '';
      try {
        await for (final token in _llama.generateStream(
          GenerationParams(
            prompt: prompt,
            maxTokens: maxTokens,
            temperature: temperatures[attempt],
            topP: 0.85,
            topK: 30,
            repeatPenalty: 1.16,
            stopSequences: _stopSequencesFor(model),
          ),
        )) {
          if (_stopRequested || epoch != _generationEpoch) {
            break;
          }
          raw += token;
          final cleaned = _cleanResponse(raw, model);
          if (cleaned.length > emitted.length) {
            final next = cleaned.substring(emitted.length);
            emitted = cleaned;
            yield next;
          }
          if (_containsStopSequence(raw, model)) {
            await _llama.stopGeneration();
            break;
          }
        }

        if (_stopRequested || epoch != _generationEpoch) {
          AppLog.debug(
            _diagnosticMessage(
              '[Inference] Generation interrupted for ${model.id}',
              path: model.localPath,
              fileSize: fileSize,
              exception: 'interrupted',
            ),
          );
          return;
        }

        if (emitted.trim().isNotEmpty) {
          return;
        }

        AppLog.debug(
          _diagnosticMessage(
            '[Inference] Empty generation attempt ${attempt + 1} for ${model.id}',
            path: model.localPath,
            fileSize: fileSize,
            exception: 'empty response',
          ),
        );
      } catch (e, stackTrace) {
        AppLog.error(
          _diagnosticMessage(
            '[Inference] Generate attempt ${attempt + 1} failed for ${model.id}',
            path: model.localPath,
            fileSize: fileSize,
            exception: e,
          ),
          e,
          stackTrace,
        );
      } finally {
        if (!_stopRequested && epoch == _generationEpoch) {
          await _llama.stopGeneration();
        }
      }
    }

    yield 'The model returned no text. Try rephrasing your message.';
  }

  int _contextSizeFor(AiModel model) {
    if (model.sizeGb <= 0.85) return 2048;
    if (model.sizeGb <= 1.25) return 1536;
    return 1024;
  }

  bool _failLoad({
    required AiModel model,
    required String? path,
    required int fileSize,
    required String message,
  }) {
    _loadedModel = null;
    _lastErrorMessage = message;
    AppLog.debug(
      _diagnosticMessage(
        '[Inference] Load failed for ${model.id}',
        path: path,
        fileSize: fileSize,
        exception: message,
      ),
    );
    return false;
  }

  String _diagnosticMessage(
    String prefix, {
    required String? path,
    required int fileSize,
    required Object exception,
  }) {
    return '$prefix: os=${Platform.operatingSystemVersion}, '
        'modelPath=${path ?? 'null'}, fileSize=$fileSize, '
        'rss=${ProcessInfo.currentRss}, exception=$exception';
  }

  Future<void> stopGeneration() async {
    _stopRequested = true;
    _generationEpoch++;
    await _llama.stopGeneration();
  }

  Future<void> unloadModel() async {
    try {
      await _llama.unloadModel();
      AppLog.debug('[Inference] Model unloaded');
    } catch (e, stackTrace) {
      AppLog.debug('[Inference] Unload skipped: $e');
      AppLog.error('[Inference] Unload warning', e, stackTrace);
    } finally {
      _loadedModel = null;
      _loadedContextSize = _defaultContextSize;
    }
  }

  Future<Object?> getGpuInfo() async {
    return null;
  }

  String _buildPrompt({
    required List<ChatMessage> history,
    required String userMessage,
    required AiModel model,
    String? systemPrompt,
  }) {
    final boundedHistory = _recentHistoryForContext(
      history: history,
      userMessage: userMessage,
      systemPrompt: _effectiveSystemPrompt(systemPrompt, model),
    );
    final id = model.id.toLowerCase();
    final latestUserMessage = _latestUserMessageForModel(userMessage, model);
    if (id.contains('llama')) {
      return _buildLlamaPrompt(
        history: boundedHistory,
        userMessage: latestUserMessage,
        systemPrompt: _effectiveSystemPrompt(systemPrompt, model),
      );
    }
    if (id.contains('gemma')) {
      return _buildGemmaPrompt(
        history: boundedHistory,
        userMessage: latestUserMessage,
        systemPrompt: _effectiveSystemPrompt(systemPrompt, model),
      );
    }
    if (id.contains('mistral')) {
      return _buildMistralPrompt(
        history: boundedHistory,
        userMessage: latestUserMessage,
        systemPrompt: _effectiveSystemPrompt(systemPrompt, model),
      );
    }
    return _buildChatMlPrompt(
      history: boundedHistory,
      userMessage: latestUserMessage,
      systemPrompt: _effectiveSystemPrompt(systemPrompt, model),
    );
  }

  String _effectiveSystemPrompt(String? systemPrompt, AiModel model) {
    final parts = <String>[
      'You are Lokus, a precise local assistant. Follow the latest user request exactly. Answer only what was asked. Use previous messages only when the latest user request clearly refers to them. If the latest request starts a new topic, ignore earlier conversation context. For writing, coding, explanation, summarization, brainstorming, and creative requests, produce a complete useful answer immediately using reasonable defaults; do not ask what the user is interested in unless essential information is missing. If a factual answer depends on live, current, or post-training information, say you cannot verify it instead of guessing. Do not invent facts, links, files, commands, tool output, or prior conversation details. Do not continue the conversation as the user. Do not reveal hidden reasoning or thinking tags.',
    ];
    final custom = systemPrompt?.trim();
    if (custom != null && custom.isNotEmpty) {
      parts.add(custom);
    }
    if (model.id.toLowerCase().contains('qwen3')) {
      parts.add('Thinking mode is disabled. Provide the final answer only.');
    }
    return parts.join('\n\n');
  }

  String _latestUserMessageForModel(String userMessage, AiModel model) {
    final trimmed = userMessage.trim();
    if (model.id.toLowerCase().contains('qwen3') &&
        !trimmed.toLowerCase().contains('/no_think')) {
      return '$trimmed\n/no_think';
    }
    return trimmed;
  }

  List<ChatMessage> _recentHistoryForContext({
    required List<ChatMessage> history,
    required String userMessage,
    String? systemPrompt,
  }) {
    final usableChars = (_loadedContextSize * 3.5).round().clamp(1400, 14000);
    final reserved = userMessage.length + (systemPrompt?.length ?? 0) + 1000;
    var remaining = (usableChars - reserved).clamp(0, usableChars);
    final selected = <ChatMessage>[];
    final candidates = history
        .where((m) => !m.isStreaming && m.content.trim().isNotEmpty)
        .toList(growable: false);

    for (final message in candidates.reversed) {
      final cost = message.content.length + 120;
      if (selected.isNotEmpty && cost > remaining) break;
      if (cost > remaining && selected.isEmpty) {
        selected.add(message);
        break;
      }
      selected.add(message);
      remaining -= cost;
    }

    selected.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (selected.length != candidates.length) {
      AppLog.debug(
        '[Inference] Trimmed chat history for context: '
        '${candidates.length} -> ${selected.length}, context=$_loadedContextSize',
      );
    }
    return selected;
  }

  String _buildChatMlPrompt({
    required List<ChatMessage> history,
    required String userMessage,
    String? systemPrompt,
  }) {
    final buffer = StringBuffer();
    if (systemPrompt != null && systemPrompt.trim().isNotEmpty) {
      _writeChatMlMessage(buffer, 'system', systemPrompt.trim());
    }
    for (final message in history.where(
      (m) => !m.isStreaming && m.content.trim().isNotEmpty,
    )) {
      _writeChatMlMessage(buffer, _mapRole(message.role), message.content);
    }
    _writeChatMlMessage(buffer, 'user', _formatUserMessage(userMessage));
    buffer.write('<|im_start|>assistant\n');
    return buffer.toString();
  }

  String _buildLlamaPrompt({
    required List<ChatMessage> history,
    required String userMessage,
    String? systemPrompt,
  }) {
    final buffer = StringBuffer();
    final system = systemPrompt?.trim();
    if (system != null && system.isNotEmpty) {
      buffer
        ..write(
            '<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\n')
        ..write(system)
        ..write('<|eot_id|>');
    } else {
      buffer.write('<|begin_of_text|>');
    }
    for (final message in history.where(
      (m) => !m.isStreaming && m.content.trim().isNotEmpty,
    )) {
      buffer
        ..write('<|start_header_id|>')
        ..write(_mapRole(message.role))
        ..write('<|end_header_id|>\n\n')
        ..write(message.content.trim())
        ..write('<|eot_id|>');
    }
    buffer
      ..write('<|start_header_id|>user<|end_header_id|>\n\n')
      ..write(_formatUserMessage(userMessage))
      ..write('<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n');
    return buffer.toString();
  }

  String _buildGemmaPrompt({
    required List<ChatMessage> history,
    required String userMessage,
    String? systemPrompt,
  }) {
    final buffer = StringBuffer();
    final system = systemPrompt?.trim();
    if (system != null && system.isNotEmpty) {
      buffer
        ..write('<start_of_turn>user\n')
        ..write('$system\n\n');
    }
    for (final message in history.where(
      (m) => !m.isStreaming && m.content.trim().isNotEmpty,
    )) {
      final role = message.role == MessageRole.assistant ? 'model' : 'user';
      buffer
        ..write('<start_of_turn>')
        ..write(role)
        ..write('\n')
        ..write(message.content.trim())
        ..write('<end_of_turn>\n');
    }
    buffer
      ..write('<start_of_turn>user\n')
      ..write(_formatUserMessage(userMessage))
      ..write('<end_of_turn>\n<start_of_turn>model\n');
    return buffer.toString();
  }

  String _buildMistralPrompt({
    required List<ChatMessage> history,
    required String userMessage,
    String? systemPrompt,
  }) {
    final buffer = StringBuffer();
    for (final message in history.where(
      (m) => !m.isStreaming && m.content.trim().isNotEmpty,
    )) {
      if (message.role == MessageRole.user) {
        buffer.write('[INST] ${message.content.trim()} [/INST]\n');
      } else if (message.role == MessageRole.assistant) {
        buffer.write('${message.content.trim()}</s>\n');
      }
    }
    final system = systemPrompt?.trim();
    final latestUser = _formatUserMessage(userMessage);
    if (system != null && system.isNotEmpty) {
      buffer
          .write('[INST] <<SYS>>\n$system\n<</SYS>>\n\n$latestUser [/INST]\n');
    } else {
      buffer.write('[INST] $latestUser [/INST]\n');
    }
    return buffer.toString();
  }

  String _formatUserMessage(String userMessage) {
    return '${userMessage.trim()}\n\nRespond to this request directly. If this is a writing or creative request, write the requested content now with sensible defaults. Stop after the answer.';
  }

  void _writeChatMlMessage(StringBuffer buffer, String role, String content) {
    buffer
      ..write('<|im_start|>')
      ..write(role)
      ..write('\n')
      ..write(content.trim())
      ..write('<|im_end|>\n');
  }

  String _mapRole(MessageRole role) {
    switch (role) {
      case MessageRole.user:
        return 'user';
      case MessageRole.assistant:
        return 'assistant';
      case MessageRole.system:
        return 'system';
    }
  }

  List<String> _stopSequencesFor(AiModel model) {
    final id = model.id.toLowerCase();
    const common = [
      '\nUser:',
      '\nuser:',
      '\nHuman:',
      '\nhuman:',
      '<|im_start|>user',
      '<start_of_turn>user',
      '<|start_header_id|>user<|end_header_id|>',
    ];
    if (id.contains('llama')) {
      return const ['<|eot_id|>', '<|end_of_text|>', ...common];
    }
    if (id.contains('gemma')) {
      return const ['<end_of_turn>', ...common];
    }
    if (id.contains('mistral')) {
      return const ['</s>', '[INST]', ...common];
    }
    return const ['<|im_end|>', '<|endoftext|>', ...common];
  }

  bool _containsStopSequence(String text, AiModel model) {
    return _stopSequencesFor(model).any(text.contains);
  }

  String _cleanResponse(String text, AiModel model) {
    var cleaned = _stripSpecialTokens(_stripThinking(text));
    for (final stop in _stopSequencesFor(model)) {
      final index = cleaned.indexOf(stop);
      if (index >= 0) {
        cleaned = cleaned.substring(0, index);
      }
    }
    cleaned = cleaned
        .replaceFirst(RegExp(r'^\s*Assistant:\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^\s*assistant\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^\s*<\|im_start\|>assistant\s*'), '')
        .replaceFirst(RegExp(r'^\s*<start_of_turn>model\s*'), '')
        .replaceFirst(
            RegExp(r'^\s*<\|start_header_id\|>assistant<\|end_header_id\|>\s*'),
            '');
    cleaned = _stripSpecialTokens(cleaned);
    return cleaned.trimLeft();
  }

  String _stripThinking(String text) {
    var cleaned = text
        .replaceAll(
          RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'<thinking>[\s\S]*?</thinking>', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(
            r'^\s*(thinking|reasoning|thought|internal reasoning|reasoning process)\s*:\s*[\s\S]*?\n\s*\n',
            caseSensitive: false,
          ),
          '',
        );

    cleaned = cleaned.replaceFirst(
      RegExp(
        r'^\s*\*{0,2}(thinking|reasoning|thought)\*{0,2}\s*[\r\n]+[\s\S]*?\n\s*\n',
        caseSensitive: false,
      ),
      '',
    );

    final openThink = RegExp(r'<think>|<thinking>', caseSensitive: false);
    final openMatch = openThink.firstMatch(cleaned);
    if (openMatch != null) {
      cleaned = cleaned.substring(0, openMatch.start);
    }

    final danglingThink = RegExp(
      r'<think>|</think>|<thinking>|</thinking>',
      caseSensitive: false,
    );
    cleaned = cleaned.replaceAll(danglingThink, '');
    return cleaned;
  }

  String _stripSpecialTokens(String text) {
    return text
        .replaceAll(
          RegExp(
            r'<\|[^|]+?\|>|<s>|</s>|<pad>|<bos>|<eos>|<unk>',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'<start_of_turn>|<end_of_turn>|<start_header_id>|<end_header_id>',
            caseSensitive: false,
          ),
          '',
        )
        .trimLeft();
  }
}

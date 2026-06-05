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

class InferenceService {
  final FlutterLlama _llama = FlutterLlama.instance;
  AiModel? _loadedModel;
  bool _isLoading = false;
  int _generationEpoch = 0;
  bool _stopRequested = false;

  bool get isModelLoaded => _loadedModel != null;
  AiModel? get loadedModel => _loadedModel;
  bool get isLoading => _isLoading;

  Future<bool> loadModel(AiModel model) async {
    if (model.localPath == null) return false;
    final modelFile = File(model.localPath!);
    if (!await modelFile.exists()) {
      AppLog.debug('[Inference] Load failed: file not found for ${model.id}');
      return false;
    }
    if (!await _looksLikeGguf(modelFile)) {
      AppLog.debug('[Inference] Load failed: invalid GGUF file ${model.id}');
      return false;
    }

    _isLoading = true;
    try {
      final ok = await _llama.loadModel(
        LlamaConfig(
          modelPath: model.localPath!,
          nThreads: 2,
          nGpuLayers: 0,
          contextSize: 2048,
          batchSize: 64,
        ),
      );
      if (!ok) {
        _loadedModel = null;
        return false;
      }
      _loadedModel = model;
      AppLog.debug('[Inference] Loaded: ${model.id}');
      return true;
    } catch (e, stackTrace) {
      AppLog.error('[Inference] Load failed for ${model.id}', e, stackTrace);
      _loadedModel = null;
      return false;
    } finally {
      _isLoading = false;
    }
  }

  Stream<String> generateStream({
    required List<ChatMessage> history,
    required String userMessage,
    double temperature = 0.7,
    int maxTokens = 512,
    String? systemPrompt,
  }) async* {
    if (_loadedModel == null) {
      throw Exception('No model loaded. Please select a downloaded model.');
    }

    final epoch = ++_generationEpoch;
    _stopRequested = false;
    final model = _loadedModel!;
    final prompt = _buildPrompt(
      history: history,
      userMessage: userMessage,
      systemPrompt: systemPrompt,
      model: model,
    );

    var raw = '';
    var emitted = '';
    try {
      await for (final token in _llama.generateStream(
        GenerationParams(
          prompt: prompt,
          maxTokens: maxTokens,
          temperature: temperature <= 0 ? 0.8 : temperature,
          topP: 0.95,
          topK: 50,
          repeatPenalty: 1.1,
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
    } finally {
      if (_stopRequested || epoch != _generationEpoch) {
        await _llama.stopGeneration();
      }
    }
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
    final id = model.id.toLowerCase();
    if (id.contains('llama')) {
      return _buildLlamaPrompt(
        history: history,
        userMessage: userMessage,
        systemPrompt: systemPrompt,
      );
    }
    if (id.contains('gemma')) {
      return _buildGemmaPrompt(
        history: history,
        userMessage: userMessage,
        systemPrompt: systemPrompt,
      );
    }
    if (id.contains('mistral')) {
      return _buildMistralPrompt(
        history: history,
        userMessage: userMessage,
        systemPrompt: systemPrompt,
      );
    }
    return _buildChatMlPrompt(
      history: history,
      userMessage: userMessage,
      systemPrompt: systemPrompt,
    );
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
    _writeChatMlMessage(buffer, 'user', userMessage);
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
      ..write(userMessage.trim())
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
      ..write(userMessage.trim())
      ..write('<end_of_turn>\n<start_of_turn>model\n');
    return buffer.toString();
  }

  String _buildMistralPrompt({
    required List<ChatMessage> history,
    required String userMessage,
    String? systemPrompt,
  }) {
    final buffer = StringBuffer();
    final system = systemPrompt?.trim();
    if (system != null && system.isNotEmpty) {
      buffer.write('$system\n\n');
    }
    for (final message in history.where(
      (m) => !m.isStreaming && m.content.trim().isNotEmpty,
    )) {
      if (message.role == MessageRole.user) {
        buffer.write('[INST] ${message.content.trim()} [/INST]\n');
      } else if (message.role == MessageRole.assistant) {
        buffer.write('${message.content.trim()}</s>\n');
      }
    }
    buffer.write('[INST] ${userMessage.trim()} [/INST]\n');
    return buffer.toString();
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
    if (id.contains('llama')) {
      return const ['<|eot_id|>', '<|end_of_text|>'];
    }
    if (id.contains('gemma')) {
      return const ['<end_of_turn>'];
    }
    if (id.contains('mistral')) {
      return const ['</s>'];
    }
    return const ['<|im_end|>'];
  }

  bool _containsStopSequence(String text, AiModel model) {
    return _stopSequencesFor(model).any(text.contains);
  }

  String _cleanResponse(String text, AiModel model) {
    var cleaned = _stripThinking(text);
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

  Future<bool> _looksLikeGguf(File file) async {
    final raf = await file.open();
    try {
      if (await raf.length() < 4) return false;
      final bytes = await raf.read(4);
      return bytes.length == 4 &&
          bytes[0] == 0x47 &&
          bytes[1] == 0x47 &&
          bytes[2] == 0x55 &&
          bytes[3] == 0x46;
    } finally {
      await raf.close();
    }
  }
}

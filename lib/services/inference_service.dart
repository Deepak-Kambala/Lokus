import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_llama/flutter_llama.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/chat/domain/entities/chat_message.dart';
import '../features/models/domain/entities/ai_model.dart';

final inferenceServiceProvider = Provider<InferenceService>((ref) {
  return InferenceService();
});

class InferenceService {
  final FlutterLlama _llama = FlutterLlama.instance;
  AiModel? _loadedModel;
  bool _isLoading = false;

  bool get isModelLoaded => _loadedModel != null;
  AiModel? get loadedModel => _loadedModel;
  bool get isLoading => _isLoading;

  Future<bool> loadModel(AiModel model) async {
    if (model.localPath == null) return false;
    final modelFile = File(model.localPath!);
    if (!await modelFile.exists()) {
      debugPrint('[Inference] Load failed: file not found ${model.localPath}');
      return false;
    }
    if (!await _looksLikeGguf(modelFile)) {
      debugPrint('[Inference] Load failed: invalid GGUF file ${model.localPath}');
      return false;
    }

    _isLoading = true;
    try {
      final ok = await _llama.loadModel(
        LlamaConfig(
          modelPath: model.localPath!,
          nThreads: 4,
          nGpuLayers: 0,
          contextSize: 2048,
        ),
      );
      if (!ok) {
        _loadedModel = null;
        return false;
      }
      _loadedModel = model;
      debugPrint('[Inference] Loaded: ${model.name}');
      return true;
    } catch (e) {
      debugPrint('[Inference] Load failed: $e');
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

    final prompt = _buildPrompt(
      history: history,
      userMessage: userMessage,
      systemPrompt: systemPrompt,
      model: _loadedModel!,
    );
    debugPrint('[Inference] Prompt tail: ${prompt.length > 300 ? prompt.substring(prompt.length - 300) : prompt}');

    final response = await _llama.generate(
      GenerationParams(
        prompt: prompt,
        maxTokens: maxTokens,
        temperature: temperature <= 0 ? 0.8 : temperature,
        topP: 0.95,
        topK: 50,
        repeatPenalty: 1.1,
        stopSequences: _stopSequencesFor(_loadedModel!),
      ),
    );

    final cleaned = _cleanResponse(response.text, _loadedModel!);
    for (final codePoint in cleaned.runes) {
      yield String.fromCharCode(codePoint);
      await Future<void>.delayed(const Duration(milliseconds: 8));
    }
  }

  Future<void> stopGeneration() async {
    await _llama.stopGeneration();
  }

  Future<void> unloadModel() async {
    await _llama.unloadModel();
    _loadedModel = null;
    debugPrint('[Inference] Model unloaded');
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
        ..write('<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\n')
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
    if (id.contains('mistral')) {
      return const ['</s>'];
    }
    return const ['<|im_end|>'];
  }

  String _cleanResponse(String text, AiModel model) {
    var cleaned = text;
    for (final stop in _stopSequencesFor(model)) {
      final index = cleaned.indexOf(stop);
      if (index >= 0) {
        cleaned = cleaned.substring(0, index);
      }
    }
    return cleaned.trimLeft();
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

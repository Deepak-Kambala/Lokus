import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/constants/hive_constants.dart';
import '../../../services/storage_service.dart';
import '../../chat/domain/entities/chat_message.dart';
import '../../chat/domain/entities/conversation.dart';

// ── Repository ──────────────────────────────────────────────────────────────

final conversationsRepositoryProvider =
    Provider<ConversationsRepository>((ref) {
  return ConversationsRepository(ref.read(storageServiceProvider));
});

class ConversationsRepository {
  final StorageService _storageService;

  ConversationsRepository(this._storageService);

  Box<Conversation> get _convoBox =>
      Hive.box<Conversation>(HiveConstants.conversationsBox);
  Box<ChatMessage> get _msgBox =>
      Hive.box<ChatMessage>(HiveConstants.messagesBox);

  List<Conversation> getAllConversations() {
    final convos = _convoBox.values.whereType<Conversation>().toList();
    convos.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return convos;
  }

  Conversation? getById(String id) => _convoBox.get(id);

  Future<Conversation> createConversation({
    required String modelId,
    required String modelName,
    String? systemPrompt,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();
    final convo = Conversation(
      id: id,
      title: 'New Chat',
      modelId: modelId,
      modelName: modelName,
      createdAt: now,
      updatedAt: now,
      systemPrompt: systemPrompt,
    );
    await _convoBox.put(id, convo);
    await _persistConversation(convo);
    return convo;
  }

  Future<void> saveConversation(Conversation convo) async {
    await _convoBox.put(convo.id, convo);
    await _persistConversation(convo);
  }

  Future<void> renameConversation(String id, String newTitle) async {
    final convo = _convoBox.get(id);
    if (convo != null) {
      final updated = convo.copyWith(title: newTitle);
      await _convoBox.put(id, updated);
      await _persistConversation(updated);
    }
  }

  Future<void> togglePin(String id) async {
    final convo = _convoBox.get(id);
    if (convo != null) {
      final updated = convo.copyWith(isPinned: !convo.isPinned);
      await _convoBox.put(id, updated);
      await _persistConversation(updated);
    }
  }

  Future<void> deleteConversation(String id) async {
    final convo = _convoBox.get(id);
    await _convoBox.delete(id);
    // Delete associated messages
    final toDelete = _msgBox.values
        .whereType<ChatMessage>()
        .where((m) => m.conversationId == id)
        .map((m) => m.key)
        .toList();
    await _msgBox.deleteAll(toDelete);
    if (convo != null) {
      await _deleteConversationFile(convo);
    }
  }

  Future<void> removeEmptyConversations() async {
    final emptyIds = _convoBox.values
        .whereType<Conversation>()
        .where((convo) =>
            convo.messageCount == 0 &&
            !_msgBox.values
                .whereType<ChatMessage>()
                .any((m) => m.conversationId == convo.id))
        .map((convo) => convo.id)
        .toList();

    for (final id in emptyIds) {
      await deleteConversation(id);
    }
  }

  List<ChatMessage> getMessages(String conversationId) {
    return _msgBox.values
        .whereType<ChatMessage>()
        .where((m) => m.conversationId == conversationId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Future<int> restoreConversationsFromStorage() async {
    final root = _storageService.storageFolderPath;
    if (root == null || root.isEmpty) return 0;

    final chatsDir = Directory(p.join(root, 'chats'));
    if (!await chatsDir.exists()) return 0;

    var restored = 0;
    await for (final entity
        in chatsDir.list(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.json')) {
        continue;
      }

      final restoredConversation = await _restoreConversationFile(entity);
      if (restoredConversation) {
        restored++;
      }
    }
    return restored;
  }

  Future<void> addMessage(ChatMessage message) async {
    await _msgBox.put(message.id, message);

    // Update conversation metadata
    final convo = _convoBox.get(message.conversationId);
    if (convo != null) {
      final updated = convo.copyWith(
        updatedAt: DateTime.now(),
        messageCount: convo.messageCount + 1,
        lastMessage: message.content.length > 60
            ? '${message.content.substring(0, 60)}...'
            : message.content,
        // Auto-title from first user message
        title: convo.messageCount == 0 && message.role == MessageRole.user
            ? (message.content.length > 40
                ? message.content.substring(0, 40)
                : message.content)
            : null,
      );
      await _convoBox.put(convo.id, updated);
      await _persistConversation(updated);
    }
  }

  Future<void> updateMessage(ChatMessage message) async {
    await _msgBox.put(message.id, message);
    final convo = _convoBox.get(message.conversationId);
    if (convo != null) {
      await _persistConversation(convo);
    }
  }

  Future<void> deleteMessage(String messageId) async {
    final message = _msgBox.get(messageId);
    await _msgBox.delete(messageId);
    if (message != null) {
      final convo = _convoBox.get(message.conversationId);
      if (convo != null) {
        final messages = getMessages(convo.id);
        final lastMessage = messages.isEmpty
            ? null
            : (messages.last.content.length > 60
                ? '${messages.last.content.substring(0, 60)}...'
                : messages.last.content);
        final updated = convo.copyWith(
          messageCount: messages.length,
          lastMessage: lastMessage,
          clearLastMessage: lastMessage == null,
        );
        await _convoBox.put(convo.id, updated);
        await _persistConversation(updated);
      }
    }
  }

  Future<File> exportAllConversations() async {
    final root = _storageService.storageFolderPath;
    if (root == null || root.isEmpty) {
      throw FileSystemException('Storage folder is not configured.');
    }

    final exportDir = Directory(p.join(root, 'exports'));
    await exportDir.create(recursive: true);

    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final file = File(p.join(exportDir.path, 'lokus_chats_$timestamp.json'));

    final conversations = getAllConversations();
    final payload = const JsonEncoder.withIndent('  ').convert({
      'app': 'Lokus',
      'exportedAt': DateTime.now().toIso8601String(),
      'conversationCount': conversations.length,
      'conversations': conversations.map((convo) {
        final messages = getMessages(convo.id);
        return {
          'id': convo.id,
          'title': convo.title,
          'modelId': convo.modelId,
          'modelName': convo.modelName,
          'createdAt': convo.createdAt.toIso8601String(),
          'updatedAt': convo.updatedAt.toIso8601String(),
          'isPinned': convo.isPinned,
          'systemPrompt': convo.systemPrompt,
          'messages': messages.map(_messageToJson).toList(),
        };
      }).toList(),
    });

    await file.writeAsString(payload, flush: true);
    return file;
  }

  Future<File> exportConversation(String conversationId) async {
    final root = _storageService.storageFolderPath;
    if (root == null || root.isEmpty) {
      throw FileSystemException('Storage folder is not configured.');
    }
    final convo = _convoBox.get(conversationId);
    if (convo == null) {
      throw FileSystemException('Conversation not found.');
    }

    final exportDir = Directory(p.join(root, 'exports'));
    await exportDir.create(recursive: true);

    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final title = _safePathPart(convo.title).isEmpty
        ? 'chat'
        : _safePathPart(convo.title);
    final file = File(p.join(exportDir.path, '${title}_$timestamp.json'));
    final messages = getMessages(convo.id);
    final payload = const JsonEncoder.withIndent('  ').convert({
      'app': 'Lokus',
      'exportedAt': DateTime.now().toIso8601String(),
      'conversation': {
        'id': convo.id,
        'title': convo.title,
        'modelId': convo.modelId,
        'modelName': convo.modelName,
        'createdAt': convo.createdAt.toIso8601String(),
        'updatedAt': convo.updatedAt.toIso8601String(),
        'isPinned': convo.isPinned,
        'systemPrompt': convo.systemPrompt,
        'messages': messages.map(_messageToJson).toList(),
      },
    });
    await file.writeAsString(payload, flush: true);
    return file;
  }

  Future<void> _persistConversation(Conversation convo) async {
    final root = _storageService.storageFolderPath;
    if (root == null || root.isEmpty) return;

    final dir = Directory(p.join(root, 'chats', _safePathPart(convo.modelId)));
    await dir.create(recursive: true);

    final messages = getMessages(convo.id);
    final file = File(p.join(dir.path, '${_safePathPart(convo.id)}.json'));
    final payload = const JsonEncoder.withIndent('  ').convert({
      'id': convo.id,
      'title': convo.title,
      'modelId': convo.modelId,
      'modelName': convo.modelName,
      'createdAt': convo.createdAt.toIso8601String(),
      'updatedAt': convo.updatedAt.toIso8601String(),
      'isPinned': convo.isPinned,
      'messageCount': messages.length,
      'lastMessage': convo.lastMessage,
      'systemPrompt': convo.systemPrompt,
      'messages': messages.map(_messageToJson).toList(),
    });
    await file.writeAsString(payload, flush: true);
  }

  Future<bool> _restoreConversationFile(File file) async {
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return false;

      final convoJson = decoded['conversation'] is Map
          ? Map<String, dynamic>.from(decoded['conversation'] as Map)
          : decoded;
      final id = _jsonString(convoJson['id']);
      if (id == null || id.isEmpty || _convoBox.containsKey(id)) {
        return false;
      }

      final messagesJson = convoJson['messages'];
      final messages = messagesJson is List
          ? messagesJson
              .whereType<Map>()
              .map((m) => _messageFromJson(Map<String, dynamic>.from(m), id))
              .whereType<ChatMessage>()
              .toList()
          : <ChatMessage>[];
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      final parentModelId = p.basename(file.parent.path);
      final modelId = _jsonString(convoJson['modelId']) ?? parentModelId;
      final modelName = _jsonString(convoJson['modelName']) ?? modelId;
      final createdAt =
          _jsonDate(convoJson['createdAt']) ?? _firstMessageDate(messages);
      final updatedAt =
          _jsonDate(convoJson['updatedAt']) ?? _lastMessageDate(messages);
      final lastContent = messages.isEmpty ? null : messages.last.content;
      final title = _jsonString(convoJson['title']) ??
          (messages.isNotEmpty
              ? _trimForTitle(messages.first.content)
              : 'Imported Chat');

      final convo = Conversation(
        id: id,
        title: title.isEmpty ? 'Imported Chat' : title,
        modelId: modelId,
        modelName: modelName,
        createdAt: createdAt ?? DateTime.now(),
        updatedAt: updatedAt ?? DateTime.now(),
        isPinned: convoJson['isPinned'] == true,
        messageCount: messages.length,
        lastMessage:
            lastContent == null ? null : _trimForLastMessage(lastContent),
        systemPrompt: _jsonString(convoJson['systemPrompt']),
      );

      await _convoBox.put(convo.id, convo);
      for (final message in messages) {
        await _msgBox.put(message.id, message);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  ChatMessage? _messageFromJson(Map<String, dynamic> json, String convoId) {
    final id = _jsonString(json['id']);
    final content = _jsonString(json['content']) ?? '';
    final timestamp = _jsonDate(json['timestamp']) ?? DateTime.now();
    if (id == null || id.isEmpty) return null;

    return ChatMessage(
      id: id,
      conversationId: _jsonString(json['conversationId']) ?? convoId,
      role: _roleFromJson(_jsonString(json['role'])),
      content: content,
      timestamp: timestamp,
      tokenCount: _jsonInt(json['tokenCount']),
      generationSeconds: _jsonDouble(json['generationSeconds']),
      tokensPerSecond: _jsonDouble(json['tokensPerSecond']),
      isStreaming: false,
      isError: json['isError'] == true,
    );
  }

  Future<void> _deleteConversationFile(Conversation convo) async {
    final root = _storageService.storageFolderPath;
    if (root == null || root.isEmpty) return;

    final file = File(p.join(
      root,
      'chats',
      _safePathPart(convo.modelId),
      '${_safePathPart(convo.id)}.json',
    ));
    if (await file.exists()) {
      await file.delete();
    }
  }

  Map<String, dynamic> _messageToJson(ChatMessage message) {
    return {
      'id': message.id,
      'conversationId': message.conversationId,
      'role': message.role.name,
      'content': message.content,
      'timestamp': message.timestamp.toIso8601String(),
      'tokenCount': message.tokenCount,
      'generationSeconds': message.generationSeconds,
      'tokensPerSecond': message.tokensPerSecond,
      'isStreaming': message.isStreaming,
      'isError': message.isError,
    };
  }

  String _safePathPart(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }

  MessageRole _roleFromJson(String? role) {
    switch (role) {
      case 'assistant':
        return MessageRole.assistant;
      case 'system':
        return MessageRole.system;
      case 'user':
      default:
        return MessageRole.user;
    }
  }

  String? _jsonString(Object? value) => value is String ? value : null;

  int? _jsonInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  double? _jsonDouble(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return null;
  }

  DateTime? _jsonDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  DateTime? _firstMessageDate(List<ChatMessage> messages) {
    return messages.isEmpty ? null : messages.first.timestamp;
  }

  DateTime? _lastMessageDate(List<ChatMessage> messages) {
    return messages.isEmpty ? null : messages.last.timestamp;
  }

  String _trimForTitle(String value) {
    final trimmed = value.trim();
    if (trimmed.length <= 40) return trimmed;
    return trimmed.substring(0, 40);
  }

  String _trimForLastMessage(String value) {
    if (value.length <= 60) return value;
    return '${value.substring(0, 60)}...';
  }
}

// ── Providers ───────────────────────────────────────────────────────────────

final conversationsRefreshProvider = StateProvider<int>((ref) => 0);

final conversationsListProvider = Provider<List<Conversation>>((ref) {
  ref.watch(conversationsRefreshProvider);
  return ref.read(conversationsRepositoryProvider).getAllConversations();
});

final currentConversationProvider = StateProvider<Conversation?>((ref) => null);

final messagesProvider =
    StateNotifierProvider.family<MessagesNotifier, List<ChatMessage>, String>(
        (ref, conversationId) {
  return MessagesNotifier(
    ref.read(conversationsRepositoryProvider),
    conversationId,
  );
});

class MessagesNotifier extends StateNotifier<List<ChatMessage>> {
  final ConversationsRepository _repo;
  final String _conversationId;
  Future<void> _updateQueue = Future<void>.value();

  MessagesNotifier(this._repo, this._conversationId)
      : super(_repo.getMessages(_conversationId)) {
    Future.microtask(_repairInterruptedMessages);
  }

  Future<void> addMessage(ChatMessage message) async {
    await _repo.addMessage(message);
    state = [...state, message];
  }

  Future<void> updateLastMessage(ChatMessage message) async {
    await _repo.updateMessage(message);
    if (state.isNotEmpty) {
      state = [...state.sublist(0, state.length - 1), message];
    }
  }

  Future<void> updateMessage(ChatMessage message) async {
    final queued = _updateQueue.then((_) async {
      ChatMessage? existing;
      for (final current in state) {
        if (current.id == message.id) {
          existing = current;
          break;
        }
      }
      if (existing != null && !existing.isStreaming && message.isStreaming) {
        return;
      }
      await _repo.updateMessage(message);
      state = [
        for (final existing in state)
          if (existing.id == message.id) message else existing,
      ];
    });
    _updateQueue = queued.catchError((_) {});
    await queued;
  }

  Future<void> deleteMessage(String messageId) async {
    await _repo.deleteMessage(messageId);
    state = state.where((m) => m.id != messageId).toList();
  }

  void refresh() {
    state = _repo.getMessages(_conversationId);
  }

  Future<void> _repairInterruptedMessages() async {
    var messages = state;
    var changed = false;

    for (final message in List<ChatMessage>.from(messages)) {
      if (!message.isStreaming) continue;

      if (message.content.trim().isEmpty) {
        await _repo.deleteMessage(message.id);
        messages = messages.where((m) => m.id != message.id).toList();
      } else {
        final repaired = message.copyWith(isStreaming: false);
        await _repo.updateMessage(repaired);
        messages = [
          for (final existing in messages)
            if (existing.id == repaired.id) repaired else existing,
        ];
      }
      changed = true;
    }

    if (changed) {
      state = messages;
    }
  }
}

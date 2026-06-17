import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/memory_model.dart';
import '../../data/repositories/hive_memory_repository.dart';

export '../../domain/entities/memory_model.dart';
export '../../domain/repositories/memory_repository.dart';

final memoryServiceProvider = Provider<MemoryService>((ref) {
  final repo = ref.watch(memoryRepositoryProvider);
  return MemoryService(repo);
});

/// High-level memory service used by the chat pipeline and UI.
class MemoryService {
  MemoryService(this._repo);

  final MemoryRepository _repo;
  static const _uuid = Uuid();

  // ─── Core CRUD ────────────────────────────────────────────────────────────

  /// Create and persist a new memory from raw text.
  Future<MemoryModel> saveMemory({
    required String content,
    required MemoryCategory category,
    double importance = 0.5,
    String? sourceConversationId,
    List<String>? keywords,
  }) {
    final now = DateTime.now();
    final memory = MemoryModel(
      id: _uuid.v4(),
      content: content.trim(),
      category: category,
      importance: importance.clamp(0.1, 1.0),
      createdAt: now,
      updatedAt: now,
      sourceConversationId: sourceConversationId,
      keywords: keywords ?? _extractKeywords(content),
    );
    return _repo.saveMemory(memory);
  }

  /// Update a memory's editable fields.
  Future<MemoryModel> updateMemory({
    required MemoryModel memory,
    String? content,
    MemoryCategory? category,
    double? importance,
  }) {
    final updated = memory.copyWith(
      content: content?.trim() ?? memory.content,
      category: category ?? memory.category,
      importance: importance?.clamp(0.1, 1.0) ?? memory.importance,
      keywords:
          content != null ? _extractKeywords(content) : memory.keywords,
    );
    return _repo.updateMemory(updated);
  }

  /// Permanently delete a memory.
  Future<void> deleteMemory(String id) => _repo.deleteMemory(id);

  /// Soft-delete (moves to Trash).
  Future<void> softDeleteMemory(String id) => _repo.softDeleteMemory(id);

  /// Restore from Trash.
  Future<void> restoreMemory(String id) => _repo.restoreMemory(id);

  /// Toggle pin state.
  Future<MemoryModel> togglePin(String id) => _repo.togglePin(id);

  /// Empty trash.
  Future<void> purgeDeletedMemories() => _repo.purgeDeletedMemories();

  // ─── Queries ──────────────────────────────────────────────────────────────

  Future<List<MemoryModel>> searchMemory(String query) =>
      _repo.searchMemory(query);

  Future<List<MemoryModel>> retrieveRelevantMemory(
    String query, {
    int limit = 5,
  }) =>
      _repo.retrieveRelevantMemory(query, limit: limit);

  Future<List<MemoryModel>> getAllMemories() => _repo.getAllMemories();

  Future<List<MemoryModel>> getDeletedMemories() =>
      _repo.getDeletedMemories();

  Future<List<MemoryModel>> getMemoriesByCategory(MemoryCategory cat) =>
      _repo.getMemoriesByCategory(cat);

  // ─── Memory Extraction (Pattern Matching) ─────────────────────────────────

  /// Tries to detect an explicit memory command in [userMessage].
  ///
  /// Returns an [ExtractedMemory] if found, or null otherwise.
  /// Works 100% offline using regex patterns.
  ExtractedMemory? extractMemory(String userMessage) {
    final text = userMessage.trim();

    // Patterns: "remember that ...", "remember I ...", "my X is Y", "I am/work at ..."
    final patterns = <_MemoryPattern>[
      _MemoryPattern(
        regex: RegExp(
          r'^remember\s+that\s+(.+)$',
          caseSensitive: false,
        ),
        group: 1,
      ),
      _MemoryPattern(
        regex: RegExp(
          r'^remember\s+(?:i\s+)?(.+)$',
          caseSensitive: false,
        ),
        group: 1,
      ),
      _MemoryPattern(
        regex: RegExp(
          r'^my\s+(.+?)\s+is\s+(.+)$',
          caseSensitive: false,
        ),
        group: 0, // uses full match
        isMyXisY: true,
      ),
      _MemoryPattern(
        regex: RegExp(
          r'^i\s+(?:am|work\s+(?:at|on)|study\s+at|love|like|prefer|use|know)\s+(.+)$',
          caseSensitive: false,
        ),
        group: 1,
      ),
    ];

    for (final p in patterns) {
      final match = p.regex.firstMatch(text);
      if (match == null) continue;

      String content;
      if (p.isMyXisY && match.groupCount >= 2) {
        final attribute = match.group(1)?.trim() ?? '';
        final value = match.group(2)?.trim() ?? '';
        content = 'User\'s $attribute is $value.';
      } else {
        final raw = match.group(p.group)?.trim() ?? '';
        content = _normaliseContent(raw);
      }

      if (content.isEmpty) continue;

      return ExtractedMemory(
        content: content,
        category: _inferCategory(content),
        importance: _inferImportance(content),
        keywords: _extractKeywords(content),
      );
    }
    return null;
  }

  // ─── Prompt Context Building ───────────────────────────────────────────────

  /// Build the memory context string to inject before the LLM prompt.
  Future<String?> buildMemoryContext(String userMessage) async {
    final memories =
        await retrieveRelevantMemory(userMessage, limit: 6);
    if (memories.isEmpty) return null;
    final buf = StringBuffer('Facts about the user:\n');
    for (final m in memories) {
      buf.writeln('- ${m.content}');
    }
    return buf.toString().trim();
  }

  // ─── Private Helpers ──────────────────────────────────────────────────────

  MemoryCategory _inferCategory(String content) {
    final lower = content.toLowerCase();
    if (_matches(lower, ['project', 'working on', 'building', 'app', 'startup', 'product'])) {
      return MemoryCategory.project;
    }
    if (_matches(lower, ['language', 'framework', 'skill', 'know', 'expert', 'learn', 'code', 'program'])) {
      return MemoryCategory.skill;
    }
    if (_matches(lower, ['like', 'love', 'prefer', 'favourite', 'favorite', 'enjoy', 'hate', 'dislike'])) {
      return MemoryCategory.preference;
    }
    if (_matches(lower, ['college', 'university', 'school', 'born', 'live', 'age', 'name', 'work at', 'company'])) {
      return MemoryCategory.personalFact;
    }
    return MemoryCategory.custom;
  }

  double _inferImportance(String content) {
    final lower = content.toLowerCase();
    // Permanent: strong identity statements
    if (_matches(lower, [
      'college', 'university', 'name', 'born', 'profession',
      'job', 'working on', 'project', 'company',
    ])) return 1.0;
    // Useful: preferences and skills
    if (_matches(lower, [
      'like', 'love', 'prefer', 'favourite', 'skill', 'know', 'language',
    ])) return 0.5;
    // Temporary: vague / generic
    return 0.3;
  }

  bool _matches(String text, List<String> keywords) =>
      keywords.any(text.contains);

  String _normaliseContent(String raw) {
    // Capitalise and ensure ends with period
    if (raw.isEmpty) return raw;
    var out = raw[0].toUpperCase() + raw.substring(1);
    if (!out.endsWith('.') && !out.endsWith('!') && !out.endsWith('?')) {
      out += '.';
    }
    return out;
  }

  List<String> _extractKeywords(String content) {
    // Simple keyword extraction: remove stop words, take meaningful tokens
    const stopWords = {
      'the', 'and', 'for', 'that', 'this', 'with', 'are', 'was',
      'have', 'has', 'had', 'not', 'but', 'what', 'from', 'they',
      'you', 'all', 'can', 'will', 'just', 'its', 'also', 'been',
      'than', 'into', 'more', 'when', 'user', 'like', 'love',
    };
    return content
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 2 && !stopWords.contains(t))
        .toSet()
        .toList();
  }
}

// ─── Value Objects ────────────────────────────────────────────────────────────

class ExtractedMemory {
  final String content;
  final MemoryCategory category;
  final double importance;
  final List<String> keywords;

  const ExtractedMemory({
    required this.content,
    required this.category,
    required this.importance,
    required this.keywords,
  });
}

class _MemoryPattern {
  final RegExp regex;
  final int group;
  final bool isMyXisY;

  const _MemoryPattern({
    required this.regex,
    required this.group,
    this.isMyXisY = false,
  });
}

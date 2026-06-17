import 'package:hive/hive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/hive_constants.dart';
import '../../domain/entities/memory_model.dart';
import '../../domain/repositories/memory_repository.dart';

export '../../domain/repositories/memory_repository.dart';

final memoryRepositoryProvider = Provider<MemoryRepository>((ref) {
  return HiveMemoryRepository();
});

/// Hive-backed implementation of [MemoryRepository].
class HiveMemoryRepository implements MemoryRepository {
  Box<MemoryModel> get _box =>
      Hive.box<MemoryModel>(HiveConstants.memoriesBox);

  // ─── Write ────────────────────────────────────────────────────────────────

  @override
  Future<MemoryModel> saveMemory(MemoryModel memory) async {
    await _box.put(memory.id, memory);
    return memory;
  }

  @override
  Future<void> deleteMemory(String id) async {
    await _box.delete(id);
  }

  @override
  Future<void> softDeleteMemory(String id) async {
    final memory = _box.get(id);
    if (memory == null) return;
    final updated = memory.copyWith(
      isDeleted: true,
      updatedAt: DateTime.now(),
    );
    await _box.put(id, updated);
  }

  @override
  Future<void> restoreMemory(String id) async {
    final memory = _box.get(id);
    if (memory == null) return;
    final updated = memory.copyWith(
      isDeleted: false,
      updatedAt: DateTime.now(),
    );
    await _box.put(id, updated);
  }

  @override
  Future<MemoryModel> updateMemory(MemoryModel memory) async {
    final updated = memory.copyWith(updatedAt: DateTime.now());
    await _box.put(memory.id, updated);
    return updated;
  }

  @override
  Future<MemoryModel> togglePin(String id) async {
    final memory = _box.get(id);
    if (memory == null) throw Exception('Memory $id not found');
    final updated = memory.copyWith(
      isPinned: !memory.isPinned,
      updatedAt: DateTime.now(),
    );
    await _box.put(id, updated);
    return updated;
  }

  @override
  Future<void> purgeDeletedMemories() async {
    final deletedIds = _box.values
        .where((m) => m.isDeleted)
        .map((m) => m.id)
        .toList();
    await _box.deleteAll(deletedIds);
  }

  // ─── Read ─────────────────────────────────────────────────────────────────

  @override
  Future<List<MemoryModel>> getAllMemories() async {
    return _box.values
        .where((m) => !m.isDeleted)
        .toList()
      ..sort(_byImportanceThenDate);
  }

  @override
  Future<List<MemoryModel>> getDeletedMemories() async {
    return _box.values
        .where((m) => m.isDeleted)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<List<MemoryModel>> getMemoriesByCategory(
      MemoryCategory category) async {
    return _box.values
        .where((m) => !m.isDeleted && m.category == category)
        .toList()
      ..sort(_byImportanceThenDate);
  }

  // ─── Search & Retrieval ───────────────────────────────────────────────────

  @override
  Future<List<MemoryModel>> searchMemory(String query) async {
    if (query.trim().isEmpty) return getAllMemories();
    final tokens = _tokenize(query);
    return _box.values
        .where((m) => !m.isDeleted && _matchesAny(m, tokens))
        .toList()
      ..sort(_byImportanceThenDate);
  }

  @override
  Future<List<MemoryModel>> retrieveRelevantMemory(
    String query, {
    int limit = 5,
  }) async {
    if (query.trim().isEmpty) {
      final all = await getAllMemories();
      return all.take(limit).toList();
    }

    final tokens = _tokenize(query);
    final active = _box.values.where((m) => !m.isDeleted).toList();

    // Score each memory based on keyword overlap + importance
    final scored = active.map((m) {
      double score = 0;
      final contentTokens = _tokenize(m.content);
      final keywordTokens =
          m.keywords.expand(_tokenize).toSet();

      // Overlap score
      for (final t in tokens) {
        if (contentTokens.contains(t)) score += 1.0;
        if (keywordTokens.contains(t)) score += 0.7;
      }

      // Multiply by importance to boost permanent memories
      score *= (0.5 + m.importance);

      // Pinned memories get a bonus
      if (m.isPinned) score += 2.0;

      return _ScoredMemory(m, score);
    }).where((s) => s.score > 0).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return scored.take(limit).map((s) => s.memory).toList();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Set<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 2 && !_stopWords.contains(t))
        .toSet();
  }

  bool _matchesAny(MemoryModel m, Set<String> tokens) {
    final text = '${m.content} ${m.keywords.join(' ')}'.toLowerCase();
    return tokens.any(text.contains);
  }

  int _byImportanceThenDate(MemoryModel a, MemoryModel b) {
    final imp = b.importance.compareTo(a.importance);
    if (imp != 0) return imp;
    return b.createdAt.compareTo(a.createdAt);
  }

  static const _stopWords = {
    'the', 'and', 'for', 'that', 'this', 'with', 'are',
    'was', 'have', 'has', 'had', 'not', 'but', 'what',
    'from', 'they', 'you', 'all', 'can', 'will', 'just',
    'its', 'also', 'been', 'than', 'into', 'more', 'when',
  };
}

class _ScoredMemory {
  final MemoryModel memory;
  final double score;
  const _ScoredMemory(this.memory, this.score);
}

import '../entities/memory_model.dart';

/// Pure domain interface — no Hive or Flutter dependencies.
abstract class MemoryRepository {
  /// Save a new memory. Returns the saved [MemoryModel].
  Future<MemoryModel> saveMemory(MemoryModel memory);

  /// Permanently hard-delete a memory by [id].
  Future<void> deleteMemory(String id);

  /// Soft-delete a memory (marks isDeleted = true).
  Future<void> softDeleteMemory(String id);

  /// Restore a soft-deleted memory.
  Future<void> restoreMemory(String id);

  /// Update mutable fields of an existing memory.
  Future<MemoryModel> updateMemory(MemoryModel memory);

  /// Find memories whose content or keywords match [query].
  Future<List<MemoryModel>> searchMemory(String query);

  /// Retrieve the top-[limit] relevant memories for a given [query] using
  /// keyword + importance scoring (no network).
  Future<List<MemoryModel>> retrieveRelevantMemory(
    String query, {
    int limit = 5,
  });

  /// All active (non-deleted) memories.
  Future<List<MemoryModel>> getAllMemories();

  /// Only soft-deleted memories.
  Future<List<MemoryModel>> getDeletedMemories();

  /// Active memories for a specific [category].
  Future<List<MemoryModel>> getMemoriesByCategory(MemoryCategory category);

  /// Toggle pin state of memory with [id].
  Future<MemoryModel> togglePin(String id);

  /// Purge all hard-deleted memories.
  Future<void> purgeDeletedMemories();
}

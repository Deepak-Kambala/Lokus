import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/memory_service.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class MemoryState {
  final List<MemoryModel> allMemories;
  final List<MemoryModel> deletedMemories;
  final List<MemoryModel> searchResults;
  final String searchQuery;
  final bool isLoading;
  final String? error;

  const MemoryState({
    this.allMemories = const [],
    this.deletedMemories = const [],
    this.searchResults = const [],
    this.searchQuery = '',
    this.isLoading = false,
    this.error,
  });

  MemoryState copyWith({
    List<MemoryModel>? allMemories,
    List<MemoryModel>? deletedMemories,
    List<MemoryModel>? searchResults,
    String? searchQuery,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return MemoryState(
      allMemories: allMemories ?? this.allMemories,
      deletedMemories: deletedMemories ?? this.deletedMemories,
      searchResults: searchResults ?? this.searchResults,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }

  // ─── Derived getters by category ──────────────────────────────────────────

  List<MemoryModel> get preferences =>
      allMemories.where((m) => m.category == MemoryCategory.preference).toList();

  List<MemoryModel> get projects =>
      allMemories.where((m) => m.category == MemoryCategory.project).toList();

  List<MemoryModel> get personalFacts =>
      allMemories
          .where((m) => m.category == MemoryCategory.personalFact)
          .toList();

  List<MemoryModel> get skills =>
      allMemories.where((m) => m.category == MemoryCategory.skill).toList();

  List<MemoryModel> get custom =>
      allMemories.where((m) => m.category == MemoryCategory.custom).toList();

  List<MemoryModel> get pinned =>
      allMemories.where((m) => m.isPinned).toList();

  List<MemoryModel> get displayList =>
      searchQuery.isEmpty ? allMemories : searchResults;
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class MemoryNotifier extends StateNotifier<MemoryState> {
  MemoryNotifier(this._service) : super(const MemoryState()) {
    loadAll();
  }

  final MemoryService _service;

  // ─── Load ──────────────────────────────────────────────────────────────────

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final all = await _service.getAllMemories();
      final deleted = await _service.getDeletedMemories();
      state = state.copyWith(
        allMemories: all,
        deletedMemories: deleted,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ─── Save ─────────────────────────────────────────────────────────────────

  Future<void> saveMemory({
    required String content,
    required MemoryCategory category,
    double importance = 0.5,
    String? sourceConversationId,
  }) async {
    try {
      await _service.saveMemory(
        content: content,
        category: category,
        importance: importance,
        sourceConversationId: sourceConversationId,
      );
      await loadAll();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // ─── Update ───────────────────────────────────────────────────────────────

  Future<void> updateMemory({
    required MemoryModel memory,
    String? content,
    MemoryCategory? category,
    double? importance,
  }) async {
    try {
      await _service.updateMemory(
        memory: memory,
        content: content,
        category: category,
        importance: importance,
      );
      await loadAll();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // ─── Delete ───────────────────────────────────────────────────────────────

  Future<void> softDeleteMemory(String id) async {
    try {
      await _service.softDeleteMemory(id);
      await loadAll();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> restoreMemory(String id) async {
    try {
      await _service.restoreMemory(id);
      await loadAll();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteMemory(String id) async {
    try {
      await _service.deleteMemory(id);
      await loadAll();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> purgeDeletedMemories() async {
    try {
      await _service.purgeDeletedMemories();
      await loadAll();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // ─── Pin ──────────────────────────────────────────────────────────────────

  Future<void> togglePin(String id) async {
    try {
      await _service.togglePin(id);
      await loadAll();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // ─── Search ───────────────────────────────────────────────────────────────

  Future<void> search(String query) async {
    state = state.copyWith(searchQuery: query);
    if (query.trim().isEmpty) {
      state = state.copyWith(searchResults: []);
      return;
    }
    try {
      final results = await _service.searchMemory(query);
      state = state.copyWith(searchResults: results);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

// ─── Providers ────────────────────────────────────────────────────────────────

final memoryNotifierProvider =
    StateNotifierProvider<MemoryNotifier, MemoryState>((ref) {
  final service = ref.watch(memoryServiceProvider);
  return MemoryNotifier(service);
});

/// Quick access to the memory service without going through the notifier.
final memoryServiceRefProvider = Provider<MemoryService>((ref) {
  return ref.watch(memoryServiceProvider);
});

import 'package:hive/hive.dart';
import '../../../../core/constants/hive_constants.dart';

part 'memory_model.g.dart';

// ─── Memory Category ────────────────────────────────────────────────────────

@HiveType(typeId: HiveTypeIds.memoryCategory)
enum MemoryCategory {
  @HiveField(0)
  preference,

  @HiveField(1)
  personalFact,

  @HiveField(2)
  project,

  @HiveField(3)
  skill,

  @HiveField(4)
  custom,
}

extension MemoryCategoryX on MemoryCategory {
  String get label {
    switch (this) {
      case MemoryCategory.preference:
        return 'Preference';
      case MemoryCategory.personalFact:
        return 'Personal Fact';
      case MemoryCategory.project:
        return 'Project';
      case MemoryCategory.skill:
        return 'Skill';
      case MemoryCategory.custom:
        return 'Custom';
    }
  }

  String get emoji {
    switch (this) {
      case MemoryCategory.preference:
        return '❤️';
      case MemoryCategory.personalFact:
        return '👤';
      case MemoryCategory.project:
        return '🚀';
      case MemoryCategory.skill:
        return '⚡';
      case MemoryCategory.custom:
        return '📌';
    }
  }
}

// ─── Memory Model ────────────────────────────────────────────────────────────

@HiveType(typeId: HiveTypeIds.memoryModel)
class MemoryModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String content;

  @HiveField(2)
  MemoryCategory category;

  /// Importance score: 0.1 = temporary, 0.5 = useful, 1.0 = permanent
  @HiveField(3)
  double importance;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  DateTime updatedAt;

  @HiveField(6)
  bool isPinned;

  @HiveField(7)
  bool isDeleted;

  /// Optional source conversation ID for traceability
  @HiveField(8)
  String? sourceConversationId;

  /// Keywords extracted for fast semantic lookup
  @HiveField(9)
  List<String> keywords;

  MemoryModel({
    required this.id,
    required this.content,
    required this.category,
    required this.importance,
    required this.createdAt,
    required this.updatedAt,
    this.isPinned = false,
    this.isDeleted = false,
    this.sourceConversationId,
    List<String>? keywords,
  }) : keywords = keywords ?? [];

  MemoryModel copyWith({
    String? content,
    MemoryCategory? category,
    double? importance,
    DateTime? updatedAt,
    bool? isPinned,
    bool? isDeleted,
    String? sourceConversationId,
    List<String>? keywords,
  }) {
    return MemoryModel(
      id: id,
      content: content ?? this.content,
      category: category ?? this.category,
      importance: importance ?? this.importance,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      isDeleted: isDeleted ?? this.isDeleted,
      sourceConversationId:
          sourceConversationId ?? this.sourceConversationId,
      keywords: keywords ?? List.from(this.keywords),
    );
  }

  @override
  String toString() =>
      'MemoryModel(id: $id, category: ${category.name}, '
      'importance: $importance, content: $content)';
}

import 'package:hive/hive.dart';
import '../../../../core/constants/hive_constants.dart';

part 'conversation.g.dart';

@HiveType(typeId: HiveTypeIds.conversation)
class Conversation extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  final String modelId;

  @HiveField(3)
  final String modelName;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  DateTime updatedAt;

  @HiveField(6)
  bool isPinned;

  @HiveField(7)
  int messageCount;

  @HiveField(8)
  String? lastMessage;

  @HiveField(9)
  String? systemPrompt;

  Conversation({
    required this.id,
    required this.title,
    required this.modelId,
    required this.modelName,
    required this.createdAt,
    required this.updatedAt,
    this.isPinned = false,
    this.messageCount = 0,
    this.lastMessage,
    this.systemPrompt,
  });

  Conversation copyWith({
    String? title,
    DateTime? updatedAt,
    bool? isPinned,
    int? messageCount,
    String? lastMessage,
    bool clearLastMessage = false,
    String? systemPrompt,
  }) {
    return Conversation(
      id: id,
      title: title ?? this.title,
      modelId: modelId,
      modelName: modelName,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      messageCount: messageCount ?? this.messageCount,
      lastMessage: clearLastMessage ? null : lastMessage ?? this.lastMessage,
      systemPrompt: systemPrompt ?? this.systemPrompt,
    );
  }
}

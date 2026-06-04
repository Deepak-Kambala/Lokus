import 'package:hive/hive.dart';
import '../../../../core/constants/hive_constants.dart';

part 'chat_message.g.dart';

@HiveType(typeId: HiveTypeIds.messageRole)
enum MessageRole {
  @HiveField(0)
  user,
  @HiveField(1)
  assistant,
  @HiveField(2)
  system,
}

@HiveType(typeId: HiveTypeIds.chatMessage)
class ChatMessage extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String conversationId;

  @HiveField(2)
  final MessageRole role;

  @HiveField(3)
  String content;

  @HiveField(4)
  final DateTime timestamp;

  @HiveField(5)
  int? tokenCount;

  @HiveField(6)
  double? generationSeconds;

  @HiveField(7)
  double? tokensPerSecond;

  @HiveField(8)
  bool isStreaming;

  @HiveField(9)
  bool isError;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.timestamp,
    this.tokenCount,
    this.generationSeconds,
    this.tokensPerSecond,
    this.isStreaming = false,
    this.isError = false,
  });

  ChatMessage copyWith({
    String? content,
    int? tokenCount,
    double? generationSeconds,
    double? tokensPerSecond,
    bool? isStreaming,
    bool? isError,
  }) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      role: role,
      content: content ?? this.content,
      timestamp: timestamp,
      tokenCount: tokenCount ?? this.tokenCount,
      generationSeconds: generationSeconds ?? this.generationSeconds,
      tokensPerSecond: tokensPerSecond ?? this.tokensPerSecond,
      isStreaming: isStreaming ?? this.isStreaming,
      isError: isError ?? this.isError,
    );
  }
}

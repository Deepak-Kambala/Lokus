// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message.dart';

class MessageRoleAdapter extends TypeAdapter<MessageRole> {
  @override
  final int typeId = 5;

  @override
  MessageRole read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MessageRole.user;
      case 1:
        return MessageRole.assistant;
      case 2:
        return MessageRole.system;
      default:
        return MessageRole.user;
    }
  }

  @override
  void write(BinaryWriter writer, MessageRole obj) {
    switch (obj) {
      case MessageRole.user:
        writer.writeByte(0);
        break;
      case MessageRole.assistant:
        writer.writeByte(1);
        break;
      case MessageRole.system:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageRoleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ChatMessageAdapter extends TypeAdapter<ChatMessage> {
  @override
  final int typeId = 4;

  @override
  ChatMessage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatMessage(
      id: fields[0] as String,
      conversationId: fields[1] as String,
      role: fields[2] as MessageRole,
      content: fields[3] as String,
      timestamp: fields[4] as DateTime,
      tokenCount: fields[5] as int?,
      generationSeconds: fields[6] as double?,
      tokensPerSecond: fields[7] as double?,
      isStreaming: fields[8] as bool,
      isError: fields[9] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ChatMessage obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.conversationId)
      ..writeByte(2)
      ..write(obj.role)
      ..writeByte(3)
      ..write(obj.content)
      ..writeByte(4)
      ..write(obj.timestamp)
      ..writeByte(5)
      ..write(obj.tokenCount)
      ..writeByte(6)
      ..write(obj.generationSeconds)
      ..writeByte(7)
      ..write(obj.tokensPerSecond)
      ..writeByte(8)
      ..write(obj.isStreaming)
      ..writeByte(9)
      ..write(obj.isError);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

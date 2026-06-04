// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation.dart';

class ConversationAdapter extends TypeAdapter<Conversation> {
  @override
  final int typeId = 3;

  @override
  Conversation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Conversation(
      id: fields[0] as String,
      title: fields[1] as String,
      modelId: fields[2] as String,
      modelName: fields[3] as String,
      createdAt: fields[4] as DateTime,
      updatedAt: fields[5] as DateTime,
      isPinned: fields[6] as bool,
      messageCount: fields[7] as int,
      lastMessage: fields[8] as String?,
      systemPrompt: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Conversation obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.modelId)
      ..writeByte(3)
      ..write(obj.modelName)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.updatedAt)
      ..writeByte(6)
      ..write(obj.isPinned)
      ..writeByte(7)
      ..write(obj.messageCount)
      ..writeByte(8)
      ..write(obj.lastMessage)
      ..writeByte(9)
      ..write(obj.systemPrompt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

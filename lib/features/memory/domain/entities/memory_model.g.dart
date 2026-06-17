// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MemoryCategoryAdapter extends TypeAdapter<MemoryCategory> {
  @override
  final int typeId = HiveTypeIds.memoryCategory;

  @override
  MemoryCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MemoryCategory.preference;
      case 1:
        return MemoryCategory.personalFact;
      case 2:
        return MemoryCategory.project;
      case 3:
        return MemoryCategory.skill;
      case 4:
        return MemoryCategory.custom;
      default:
        return MemoryCategory.custom;
    }
  }

  @override
  void write(BinaryWriter writer, MemoryCategory obj) {
    writer.writeByte(obj.index);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemoryCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MemoryModelAdapter extends TypeAdapter<MemoryModel> {
  @override
  final int typeId = HiveTypeIds.memoryModel;

  @override
  MemoryModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MemoryModel(
      id: fields[0] as String,
      content: fields[1] as String,
      category: fields[2] as MemoryCategory,
      importance: fields[3] as double,
      createdAt: fields[4] as DateTime,
      updatedAt: fields[5] as DateTime,
      isPinned: fields[6] as bool? ?? false,
      isDeleted: fields[7] as bool? ?? false,
      sourceConversationId: fields[8] as String?,
      keywords: (fields[9] as List?)?.cast<String>() ?? [],
    );
  }

  @override
  void write(BinaryWriter writer, MemoryModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.content)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.importance)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.updatedAt)
      ..writeByte(6)
      ..write(obj.isPinned)
      ..writeByte(7)
      ..write(obj.isDeleted)
      ..writeByte(8)
      ..write(obj.sourceConversationId)
      ..writeByte(9)
      ..write(obj.keywords);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemoryModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

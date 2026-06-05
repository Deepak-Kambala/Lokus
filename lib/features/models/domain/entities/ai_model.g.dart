// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AiModelAdapter extends TypeAdapter<AiModel> {
  @override
  final int typeId = 0;

  @override
  AiModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AiModel(
      id: fields[0] as String,
      name: fields[1] as String,
      provider: fields[2] as String,
      description: fields[3] as String,
      sizeGb: fields[4] as double,
      downloadUrl: fields[5] as String,
      status: fields[6] as ModelStatus,
      downloadProgress: fields[7] as double,
      localPath: fields[8] as String?,
      category: fields[9] as ModelCategory,
      version: fields[10] as String,
      releaseDate: fields[11] as DateTime,
      parameterCount: fields[12] as int,
      providerIcon: fields[13] as String,
      downloadSpeedMbps: fields[14] as double,
      etaSeconds: fields[15] as int?,
      contextLength: fields[16] as int,
      tags: (fields[17] as List).cast<String>(),
      downloadReceivedBytes: fields[18] as int? ?? 0,
      downloadTotalBytes: fields[19] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, AiModel obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.provider)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.sizeGb)
      ..writeByte(5)
      ..write(obj.downloadUrl)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.downloadProgress)
      ..writeByte(8)
      ..write(obj.localPath)
      ..writeByte(9)
      ..write(obj.category)
      ..writeByte(10)
      ..write(obj.version)
      ..writeByte(11)
      ..write(obj.releaseDate)
      ..writeByte(12)
      ..write(obj.parameterCount)
      ..writeByte(13)
      ..write(obj.providerIcon)
      ..writeByte(14)
      ..write(obj.downloadSpeedMbps)
      ..writeByte(15)
      ..write(obj.etaSeconds)
      ..writeByte(16)
      ..write(obj.contextLength)
      ..writeByte(17)
      ..write(obj.tags)
      ..writeByte(18)
      ..write(obj.downloadReceivedBytes)
      ..writeByte(19)
      ..write(obj.downloadTotalBytes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ModelStatusAdapter extends TypeAdapter<ModelStatus> {
  @override
  final int typeId = 1;

  @override
  ModelStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ModelStatus.available;
      case 1:
        return ModelStatus.downloading;
      case 2:
        return ModelStatus.paused;
      case 3:
        return ModelStatus.downloaded;
      case 4:
        return ModelStatus.failed;
      default:
        return ModelStatus.available;
    }
  }

  @override
  void write(BinaryWriter writer, ModelStatus obj) {
    switch (obj) {
      case ModelStatus.available:
        writer.writeByte(0);
        break;
      case ModelStatus.downloading:
        writer.writeByte(1);
        break;
      case ModelStatus.paused:
        writer.writeByte(2);
        break;
      case ModelStatus.downloaded:
        writer.writeByte(3);
        break;
      case ModelStatus.failed:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ModelCategoryAdapter extends TypeAdapter<ModelCategory> {
  @override
  final int typeId = 2;

  @override
  ModelCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ModelCategory.general;
      case 1:
        return ModelCategory.coding;
      case 2:
        return ModelCategory.reasoning;
      case 3:
        return ModelCategory.multimodal;
      case 4:
        return ModelCategory.instruct;
      case 5:
        return ModelCategory.chat;
      default:
        return ModelCategory.general;
    }
  }

  @override
  void write(BinaryWriter writer, ModelCategory obj) {
    switch (obj) {
      case ModelCategory.general:
        writer.writeByte(0);
        break;
      case ModelCategory.coding:
        writer.writeByte(1);
        break;
      case ModelCategory.reasoning:
        writer.writeByte(2);
        break;
      case ModelCategory.multimodal:
        writer.writeByte(3);
        break;
      case ModelCategory.instruct:
        writer.writeByte(4);
        break;
      case ModelCategory.chat:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

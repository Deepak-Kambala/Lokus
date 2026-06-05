import 'package:hive/hive.dart';
import '../../../../core/constants/hive_constants.dart';

part 'ai_model.g.dart';

@HiveType(typeId: HiveTypeIds.modelStatus)
enum ModelStatus {
  @HiveField(0)
  available,
  @HiveField(1)
  downloading,
  @HiveField(2)
  paused,
  @HiveField(3)
  downloaded,
  @HiveField(4)
  failed,
}

@HiveType(typeId: HiveTypeIds.modelCategory)
enum ModelCategory {
  @HiveField(0)
  general,
  @HiveField(1)
  coding,
  @HiveField(2)
  reasoning,
  @HiveField(3)
  multimodal,
  @HiveField(4)
  instruct,
  @HiveField(5)
  chat,
}

@HiveType(typeId: HiveTypeIds.aiModel)
class AiModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String provider;

  @HiveField(3)
  final String description;

  @HiveField(4)
  final double sizeGb;

  @HiveField(5)
  final String downloadUrl;

  @HiveField(6)
  ModelStatus status;

  @HiveField(7)
  double downloadProgress;

  @HiveField(8)
  String? localPath;

  @HiveField(9)
  final ModelCategory category;

  @HiveField(10)
  final String version;

  @HiveField(11)
  final DateTime releaseDate;

  @HiveField(12)
  final int parameterCount; // in billions * 10 (e.g. 7B = 70)

  @HiveField(13)
  final String providerIcon; // emoji or asset path

  @HiveField(14)
  double downloadSpeedMbps;

  @HiveField(15)
  int? etaSeconds;

  @HiveField(16)
  final int contextLength;

  @HiveField(17)
  final List<String> tags;

  @HiveField(18)
  final int downloadReceivedBytes;

  @HiveField(19)
  final int downloadTotalBytes;

  AiModel({
    required this.id,
    required this.name,
    required this.provider,
    required this.description,
    required this.sizeGb,
    required this.downloadUrl,
    this.status = ModelStatus.available,
    this.downloadProgress = 0.0,
    this.localPath,
    required this.category,
    required this.version,
    required this.releaseDate,
    required this.parameterCount,
    required this.providerIcon,
    this.downloadSpeedMbps = 0.0,
    this.etaSeconds,
    required this.contextLength,
    required this.tags,
    this.downloadReceivedBytes = 0,
    this.downloadTotalBytes = 0,
  });

  String get sizeString {
    if (sizeGb < 1.0) {
      return '${(sizeGb * 1024).toStringAsFixed(0)} MB';
    }
    return '${sizeGb.toStringAsFixed(2)} GB';
  }

  String get parameterString {
    final billions = parameterCount / 10.0;
    if (billions < 1.0) {
      return '${(billions * 1000).toStringAsFixed(0)}M';
    }
    return '${billions.toStringAsFixed(1)}B';
  }

  String get categoryLabel {
    switch (category) {
      case ModelCategory.general:
        return 'General';
      case ModelCategory.coding:
        return 'Coding';
      case ModelCategory.reasoning:
        return 'Reasoning';
      case ModelCategory.multimodal:
        return 'Multimodal';
      case ModelCategory.instruct:
        return 'Instruct';
      case ModelCategory.chat:
        return 'Chat';
    }
  }

  AiModel copyWith({
    ModelStatus? status,
    double? downloadProgress,
    String? localPath,
    bool clearLocalPath = false,
    double? downloadSpeedMbps,
    int? etaSeconds,
    int? downloadReceivedBytes,
    int? downloadTotalBytes,
  }) {
    return AiModel(
      id: id,
      name: name,
      provider: provider,
      description: description,
      sizeGb: sizeGb,
      downloadUrl: downloadUrl,
      status: status ?? this.status,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      localPath: clearLocalPath ? null : localPath ?? this.localPath,
      category: category,
      version: version,
      releaseDate: releaseDate,
      parameterCount: parameterCount,
      providerIcon: providerIcon,
      downloadSpeedMbps: downloadSpeedMbps ?? this.downloadSpeedMbps,
      etaSeconds: etaSeconds ?? this.etaSeconds,
      contextLength: contextLength,
      tags: tags,
      downloadReceivedBytes:
          downloadReceivedBytes ?? this.downloadReceivedBytes,
      downloadTotalBytes: downloadTotalBytes ?? this.downloadTotalBytes,
    );
  }
}

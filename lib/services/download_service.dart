import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../core/utils/app_log.dart';
import '../features/models/domain/entities/ai_model.dart';
import 'storage_service.dart';

final downloadServiceProvider = Provider<DownloadService>((ref) {
  return DownloadService(ref.read(storageServiceProvider));
});

class DownloadProgress {
  final String modelId;
  final double progress; // 0.0–1.0
  final double speedMbps;
  final int etaSeconds;
  final int receivedBytes;
  final int totalBytes;

  const DownloadProgress({
    required this.modelId,
    required this.progress,
    required this.speedMbps,
    required this.etaSeconds,
    required this.receivedBytes,
    required this.totalBytes,
  });
}

class DownloadService {
  final StorageService _storageService;

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(hours: 4),
    headers: const {'User-Agent': 'Mozilla/5.0'},
    // Follow HuggingFace CDN redirects (lfs.githubusercontent.com, etc.)
    followRedirects: true,
    maxRedirects: 10,
    validateStatus: (status) => status != null && status >= 200 && status < 300,
  ));

  final Map<String, CancelToken> _tokens = {};
  final Map<String, bool> _paused = {};

  DownloadService(this._storageService);

  Future<String> downloadModel({
    required AiModel model,
    required void Function(DownloadProgress) onProgress,
    required void Function(String localPath) onComplete,
    required void Function(String error) onError,
  }) async {
    final folder = _storageService.storageFolderPath;
    if (folder == null) {
      onError(
          'Storage folder not configured. Open Settings → Storage Location.');
      return '';
    }

    final modelsDir = Directory(p.join(folder, 'models'));
    if (!await modelsDir.exists()) await modelsDir.create(recursive: true);

    final fileName = '${model.id}.gguf';
    final finalPath = p.join(modelsDir.path, fileName);
    final tmpPath = '$finalPath.tmp';
    final finalFile = File(finalPath);
    if (await _looksLikeGguf(finalFile)) {
      onProgress(DownloadProgress(
        modelId: model.id,
        progress: 1.0,
        speedMbps: 0,
        etaSeconds: 0,
        receivedBytes: await finalFile.length(),
        totalBytes: await finalFile.length(),
      ));
      onComplete(finalPath);
      return finalPath;
    }

    // Resume support: check existing temp file size
    int startByte = 0;
    final tmpFile = File(tmpPath);
    if (await tmpFile.exists()) {
      final tmpLength = await tmpFile.length();
      if (tmpLength >= 4 && !await _looksLikeGguf(tmpFile)) {
        await tmpFile.delete();
        AppLog.debug('[Download] Deleted invalid partial file for ${model.id}');
      } else {
        startByte = tmpLength;
        AppLog.debug('[Download] Resuming ${model.id} from byte $startByte');
      }
    }

    final cancelToken = CancelToken();
    _tokens[model.id] = cancelToken;
    _paused[model.id] = false;

    DateTime lastTime = DateTime.now();
    int lastBytes = 0;

    try {
      final response = await _dio.download(
        model.downloadUrl,
        tmpPath,
        cancelToken: cancelToken,
        deleteOnError: false,
        fileAccessMode:
            startByte > 0 ? FileAccessMode.append : FileAccessMode.write,
        options: Options(
          followRedirects: true,
          maxRedirects: 10,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36',
            if (startByte > 0) 'Range': 'bytes=$startByte-',
          },
        ),
        onReceiveProgress: (received, total) {
          if (_paused[model.id] == true) return;

          final now = DateTime.now();
          final ms = now.difference(lastTime).inMilliseconds;
          double speed = 0;
          if (ms > 400) {
            speed = ((received - lastBytes) / ms * 1000) / (1024 * 1024);
            lastBytes = received;
            lastTime = now;
          }

          // total may be -1 on chunked transfer — fall back to model size
          final knownTotal =
              total > 0 ? total : (model.sizeGb * 1024 * 1024 * 1024).toInt();

          final actualReceived = startByte + received;
          final actualTotal = startByte + knownTotal;
          final progress = (actualReceived / actualTotal).clamp(0.0, 1.0);

          int eta = 0;
          if (speed > 0) {
            eta = ((actualTotal - actualReceived) / (speed * 1024 * 1024))
                .round();
          }

          onProgress(DownloadProgress(
            modelId: model.id,
            progress: progress,
            speedMbps: speed,
            etaSeconds: eta,
            receivedBytes: actualReceived,
            totalBytes: actualTotal,
          ));
        },
      );

      if (startByte > 0 && response.statusCode == 200) {
        await tmpFile.delete();
        AppLog.debug('[Download] Server ignored Range; restarting ${model.id}');
        return downloadModel(
          model: model,
          onProgress: onProgress,
          onComplete: onComplete,
          onError: onError,
        );
      }

      if (!await _looksLikeGguf(tmpFile)) {
        final reason = await _invalidDownloadReason(tmpFile, response);
        if (await tmpFile.exists()) await tmpFile.delete();
        final msg = 'Downloaded file is not a GGUF model. $reason';
        AppLog.debug('[Download] Error: $msg');
        onError(msg);
        return '';
      }

      // Rename temp to final.
      await tmpFile.rename(finalPath);
      _tokens.remove(model.id);
      _paused.remove(model.id);

      AppLog.debug('[Download] Complete: ${model.id}');
      onComplete(finalPath);
      return finalPath;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        // Paused — keep temp file for resume
        if (_paused[model.id] == true) return '';
        // Cancelled — delete temp
        if (await tmpFile.exists()) await tmpFile.delete();
        return '';
      }
      final msg = _friendlyError(e);
      AppLog.error('[Download] Error', msg);
      onError(msg);
      return '';
    } catch (e) {
      AppLog.error('[Download] Unexpected', e);
      onError('Download failed unexpectedly. Please try again.');
      return '';
    }
  }

  void pauseDownload(String modelId) {
    _paused[modelId] = true;
    _tokens[modelId]?.cancel('paused');
    _tokens.remove(modelId);
  }

  void cancelDownload(String modelId) {
    _paused[modelId] = false;
    _tokens[modelId]?.cancel('cancelled');
    _tokens.remove(modelId);
    _paused.remove(modelId);
  }

  Future<void> resumeDownload(
    AiModel model, {
    required void Function(DownloadProgress) onProgress,
    required void Function(String) onComplete,
    required void Function(String) onError,
  }) async {
    await downloadModel(
      model: model,
      onProgress: onProgress,
      onComplete: onComplete,
      onError: onError,
    );
  }

  Future<void> deleteModelFile(String localPath) async {
    final f = File(localPath);
    if (await f.exists()) await f.delete();
    // Also delete partial temp if present
    final tmp = File('$localPath.tmp');
    if (await tmp.exists()) await tmp.delete();
  }

  bool isDownloading(String modelId) => _tokens.containsKey(modelId);
  bool isPaused(String modelId) => _paused[modelId] == true;

  String _friendlyError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timed out. Check your internet connection.';
      case DioExceptionType.receiveTimeout:
        return 'Download stalled. Try pausing and resuming.';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        if (code == 401 || code == 403) {
          return 'Access denied (HTTP $code). This model may require a HuggingFace account.';
        }
        if (code == 404) {
          return 'Model file not found (HTTP 404). URL may have changed.';
        }
        return 'Server error (HTTP $code).';
      default:
        return e.message ?? 'Download failed';
    }
  }

  Future<bool> _looksLikeGguf(File file) async {
    if (!await file.exists()) return false;
    final raf = await file.open();
    try {
      if (await raf.length() < 4) return false;
      final bytes = await raf.read(4);
      return bytes.length == 4 &&
          bytes[0] == 0x47 &&
          bytes[1] == 0x47 &&
          bytes[2] == 0x55 &&
          bytes[3] == 0x46;
    } finally {
      await raf.close();
    }
  }

  Future<String> _invalidDownloadReason(File file, Response response) async {
    final contentType =
        response.headers.value(Headers.contentTypeHeader)?.toLowerCase();
    if (contentType != null &&
        (contentType.contains('text/html') ||
            contentType.contains('text/plain') ||
            contentType.contains('application/json'))) {
      return 'The server returned $contentType instead of model bytes. The URL may require access, may be rate-limited, or may have changed.';
    }

    if (!await file.exists() || await file.length() < 4) {
      return 'The downloaded file is empty or incomplete. Check storage and network connectivity.';
    }

    final raf = await file.open();
    try {
      final bytes = await raf.read(80);
      final text = String.fromCharCodes(
        bytes.where((b) => b >= 32 && b <= 126),
      ).toLowerCase();
      if (text.contains('<html') ||
          text.contains('doctype') ||
          text.contains('unauthorized') ||
          text.contains('forbidden') ||
          text.contains('not found')) {
        return 'The server returned an error page instead of model bytes. The model URL may require access or may have changed.';
      }
    } finally {
      await raf.close();
    }

    return 'The model URL may require access or may have changed.';
  }
}

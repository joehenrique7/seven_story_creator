import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class StoryCompressException implements Exception {
  StoryCompressException(this.message);
  final String message;
  @override
  String toString() => 'StoryCompressException: $message';
}

class StoryCompressor {
  static const _uuid = Uuid();

  Future<File> compressImage(
    File source, {
    int maxWidth = 1080,
    int maxHeight = 1920,
    int quality = 75,
  }) async {
    final destPath = await _buildOutputPath('webp');
    final result = await FlutterImageCompress.compressAndGetFile(
      source.path,
      destPath,
      minWidth: maxWidth,
      minHeight: maxHeight,
      quality: quality,
      format: CompressFormat.webp,
      keepExif: false,
    );
    if (result == null) {
      throw StoryCompressException('Image compression returned null.');
    }
    return File(result.path);
  }

  Future<File> compressVideo(
    File source, {
    int targetWidth = 720,
    String preset = 'veryfast',
    int crf = 28,
  }) async {
    final destPath = await _buildOutputPath('mp4');
    final completer = Completer<File>();

    await FFmpegKit.executeAsync(
      '-i "${source.path}" '
      '-vcodec libx264 -crf $crf -preset $preset '
      '-vf scale=$targetWidth:-2 '
      '-acodec aac -b:a 128k '
      '-movflags +faststart '
      '"$destPath"',
      (session) async {
        final rc = await session.getReturnCode();
        if (ReturnCode.isSuccess(rc)) {
          final output = File(destPath);
          if (await output.exists()) {
            completer.complete(output);
          } else {
            completer.completeError(
              StoryCompressException('Output file not found after compression.'),
            );
          }
        } else {
          final logs = await session.getLogsAsString();
          final partial = File(destPath);
          if (await partial.exists()) await partial.delete();
          completer.completeError(
            StoryCompressException('FFmpeg failed. Logs:\n$logs'),
          );
        }
      },
    );

    return completer.future;
  }

  Future<String> _buildOutputPath(String extension) async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/${_uuid.v4()}.$extension';
  }
}

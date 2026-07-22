import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_compress/video_compress.dart';

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
    VideoQuality quality = VideoQuality.Res1920x1080Quality,
  }) async {
    final info = await VideoCompress.compressVideo(
      source.path,
      quality: quality,
      deleteOrigin: false,
      includeAudio: true,
    );
    if (info == null || info.file == null) {
      throw StoryCompressException('Video compression returned null.');
    }
    return info.file!;
  }

  Future<String> _buildOutputPath(String extension) async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/${_uuid.v4()}.$extension';
  }
}

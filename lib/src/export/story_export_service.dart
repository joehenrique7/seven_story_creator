import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../capture/models/story_media.dart';
import '../editor/models/story_element.dart';
import 'story_compressor.dart';

class StoryExportService {
  StoryExportService({StoryCompressor? compressor})
      : _compressor = compressor ?? StoryCompressor();

  final StoryCompressor _compressor;
  static const _uuid = Uuid();

  Future<File> export({
    required StoryMedia media,
    required List<StoryElement> elements,
    double brightness = 0.0,
    double contrast = 1.0,
    double saturation = 1.0,
  }) async {
    final outDir = await _storiesDirectory();
    final id = _uuid.v4();

    final File compressed;
    if (media.type == StoryType.photo) {
      compressed = await _compressor.compressImage(media.file);
      final dest = File('${outDir.path}/$id.webp');
      await compressed.copy(dest.path);
      await _writeSidecar(
        outDir: outDir,
        id: id,
        media: media,
        compressed: dest,
        elements: elements,
        brightness: brightness,
        contrast: contrast,
        saturation: saturation,
      );
      return dest;
    } else {
      compressed = await _compressor.compressVideo(media.file);
      final dest = File('${outDir.path}/$id.mp4');
      await compressed.copy(dest.path);
      await _writeSidecar(
        outDir: outDir,
        id: id,
        media: media,
        compressed: dest,
        elements: elements,
        brightness: brightness,
        contrast: contrast,
        saturation: saturation,
      );
      return dest;
    }
  }

  Future<({StoryMedia media, List<StoryElement> elements})> loadFromSidecar(
    File sidecarFile,
  ) async {
    final json = jsonDecode(await sidecarFile.readAsString())
        as Map<String, dynamic>;
    final media = StoryMedia.fromJson(json['media'] as Map<String, dynamic>);
    final elements = (json['elements'] as List)
        .map((e) => StoryElement.fromJson(e as Map<String, dynamic>))
        .toList();
    return (media: media, elements: elements);
  }

  Future<void> _writeSidecar({
    required Directory outDir,
    required String id,
    required StoryMedia media,
    required File compressed,
    required List<StoryElement> elements,
    required double brightness,
    required double contrast,
    required double saturation,
  }) async {
    final sidecar = File('${outDir.path}/$id.json');
    final payload = {
      'version': 1,
      'media': StoryMedia(
        file: compressed,
        type: media.type,
        duration: media.duration,
        thumbnail: media.thumbnail,
      ).toJson(),
      'elements': elements.map((e) => e.toJson()).toList(),
      'filter': {
        'brightness': brightness,
        'contrast': contrast,
        'saturation': saturation,
      },
    };
    await sidecar.writeAsString(jsonEncode(payload));
  }

  Future<Directory> _storiesDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/stories');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}

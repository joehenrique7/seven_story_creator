import 'dart:io';

enum StoryType { photo, video }

class StoryMedia {
  const StoryMedia({
    required this.file,
    required this.type,
    this.duration,
    this.thumbnail,
  });

  final File file;
  final StoryType type;
  final Duration? duration;
  final File? thumbnail;

  Map<String, dynamic> toJson() => {
        'filePath': file.path,
        'type': type.name,
        'durationMs': duration?.inMilliseconds,
        'thumbnailPath': thumbnail?.path,
      };

  factory StoryMedia.fromJson(Map<String, dynamic> json) => StoryMedia(
        file: File(json['filePath'] as String),
        type: StoryType.values.byName(json['type'] as String),
        duration: json['durationMs'] != null
            ? Duration(milliseconds: json['durationMs'] as int)
            : null,
        thumbnail: json['thumbnailPath'] != null
            ? File(json['thumbnailPath'] as String)
            : null,
      );

  StoryMedia copyWith({
    File? file,
    StoryType? type,
    Duration? duration,
    File? thumbnail,
  }) =>
      StoryMedia(
        file: file ?? this.file,
        type: type ?? this.type,
        duration: duration ?? this.duration,
        thumbnail: thumbnail ?? this.thumbnail,
      );
}

import 'dart:ui';

abstract class StoryElement {
  StoryElement({
    required this.id,
    required this.position,
    this.scale = 1.0,
    this.rotation = 0.0,
  });

  final String id;

  /// Fractional position (0.0–1.0) relative to the 9:16 canvas.
  final Offset position;
  final double scale;
  final double rotation;

  String get type;

  StoryElement copyWith({Offset? position, double? scale, double? rotation});

  Map<String, dynamic> toJson();

  static StoryElement fromJson(Map<String, dynamic> json) {
    switch (json['type'] as String) {
      case 'text':
        return TextElement.fromJson(json);
      case 'sticker':
        return StickerElement.fromJson(json);
      case 'drawing':
        return DrawingElement.fromJson(json);
      default:
        throw ArgumentError('Unknown StoryElement type: ${json['type']}');
    }
  }

  Map<String, dynamic> _baseJson() => {
        'id': id,
        'type': type,
        'positionDx': position.dx,
        'positionDy': position.dy,
        'scale': scale,
        'rotation': rotation,
      };
}

// ---------------------------------------------------------------------------

class TextElement extends StoryElement {
  TextElement({
    required super.id,
    required super.position,
    super.scale,
    super.rotation,
    required this.text,
    this.color = const Color(0xFFFFFFFF),
    this.fontSize = 24.0,
    this.fontFamily,
    this.hasShadow = false,
    this.align = TextAlign.center,
  });

  final String text;
  final Color color;
  final double fontSize;
  final String? fontFamily;
  final bool hasShadow;
  final TextAlign align;

  @override
  String get type => 'text';

  @override
  TextElement copyWith({
    Offset? position,
    double? scale,
    double? rotation,
    String? text,
    Color? color,
    double? fontSize,
    String? fontFamily,
    bool? hasShadow,
    TextAlign? align,
  }) =>
      TextElement(
        id: id,
        position: position ?? this.position,
        scale: scale ?? this.scale,
        rotation: rotation ?? this.rotation,
        text: text ?? this.text,
        color: color ?? this.color,
        fontSize: fontSize ?? this.fontSize,
        fontFamily: fontFamily ?? this.fontFamily,
        hasShadow: hasShadow ?? this.hasShadow,
        align: align ?? this.align,
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        'text': text,
        'colorValue': color.value,
        'fontSize': fontSize,
        'fontFamily': fontFamily,
        'hasShadow': hasShadow,
        'align': align.index,
      };

  factory TextElement.fromJson(Map<String, dynamic> json) => TextElement(
        id: json['id'] as String,
        position: Offset(
          json['positionDx'] as double,
          json['positionDy'] as double,
        ),
        scale: json['scale'] as double,
        rotation: json['rotation'] as double,
        text: json['text'] as String,
        color: Color(json['colorValue'] as int),
        fontSize: json['fontSize'] as double,
        fontFamily: json['fontFamily'] as String?,
        hasShadow: json['hasShadow'] as bool,
        align: TextAlign.values[json['align'] as int],
      );
}

// ---------------------------------------------------------------------------

class StickerElement extends StoryElement {
  StickerElement({
    required super.id,
    required super.position,
    super.scale,
    super.rotation,
    required this.emoji,
    this.size = 48.0,
  });

  final String emoji;
  final double size;

  @override
  String get type => 'sticker';

  @override
  StickerElement copyWith({
    Offset? position,
    double? scale,
    double? rotation,
    String? emoji,
    double? size,
  }) =>
      StickerElement(
        id: id,
        position: position ?? this.position,
        scale: scale ?? this.scale,
        rotation: rotation ?? this.rotation,
        emoji: emoji ?? this.emoji,
        size: size ?? this.size,
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        'emoji': emoji,
        'size': size,
      };

  factory StickerElement.fromJson(Map<String, dynamic> json) => StickerElement(
        id: json['id'] as String,
        position: Offset(
          json['positionDx'] as double,
          json['positionDy'] as double,
        ),
        scale: json['scale'] as double,
        rotation: json['rotation'] as double,
        emoji: json['emoji'] as String,
        size: json['size'] as double,
      );
}

// ---------------------------------------------------------------------------

enum StrokeStyle { solid, dashed }

class DrawingElement extends StoryElement {
  DrawingElement({
    required super.id,
    super.position = Offset.zero,
    super.scale,
    super.rotation,
    required this.points,
    this.color = const Color(0xFFFFFFFF),
    this.strokeWidth = 4.0,
    this.style = StrokeStyle.solid,
  });

  /// Fractional offsets (0.0–1.0) relative to the canvas.
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final StrokeStyle style;

  @override
  String get type => 'drawing';

  @override
  DrawingElement copyWith({
    Offset? position,
    double? scale,
    double? rotation,
    List<Offset>? points,
    Color? color,
    double? strokeWidth,
    StrokeStyle? style,
  }) =>
      DrawingElement(
        id: id,
        position: position ?? this.position,
        scale: scale ?? this.scale,
        rotation: rotation ?? this.rotation,
        points: points ?? this.points,
        color: color ?? this.color,
        strokeWidth: strokeWidth ?? this.strokeWidth,
        style: style ?? this.style,
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        'points': points
            .map((o) => {'dx': o.dx, 'dy': o.dy})
            .toList(),
        'colorValue': color.value,
        'strokeWidth': strokeWidth,
        'style': style.name,
      };

  factory DrawingElement.fromJson(Map<String, dynamic> json) => DrawingElement(
        id: json['id'] as String,
        position: Offset(
          json['positionDx'] as double,
          json['positionDy'] as double,
        ),
        scale: json['scale'] as double,
        rotation: json['rotation'] as double,
        points: (json['points'] as List)
            .map((p) => Offset(p['dx'] as double, p['dy'] as double))
            .toList(),
        color: Color(json['colorValue'] as int),
        strokeWidth: json['strokeWidth'] as double,
        style: StrokeStyle.values.byName(json['style'] as String),
      );
}

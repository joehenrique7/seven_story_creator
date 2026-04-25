import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../capture/models/story_media.dart';
import '../editor/models/story_element.dart';
import '../editor/widgets/filter_layer.dart';

/// Read-only render of a story (media + all elements).
/// Wrap in a [RepaintBoundary] with a [GlobalKey] to capture as image.
class StoryPreviewWidget extends StatefulWidget {
  const StoryPreviewWidget({
    super.key,
    required this.media,
    required this.elements,
    this.brightness = 0.0,
    this.contrast = 1.0,
    this.saturation = 1.0,
  });

  final StoryMedia media;
  final List<StoryElement> elements;
  final double brightness;
  final double contrast;
  final double saturation;

  @override
  State<StoryPreviewWidget> createState() => _StoryPreviewWidgetState();
}

class _StoryPreviewWidgetState extends State<StoryPreviewWidget> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (widget.media.type == StoryType.video) {
      _videoController =
          VideoPlayerController.file(widget.media.file)
            ..initialize().then((_) {
              if (mounted) setState(() {});
              _videoController!.setLooping(true);
              _videoController!.play();
            });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            fit: StackFit.expand,
            children: [
              FilterLayer(
                brightness: widget.brightness,
                contrast: widget.contrast,
                saturation: widget.saturation,
                child: _buildMedia(),
              ),
              // Drawing strokes (read-only — no gesture detection)
              _ReadOnlyDrawingLayer(
                elements: widget.elements.whereType<DrawingElement>().toList(),
              ),
              // Stickers (read-only)
              _ReadOnlyStickerLayer(
                elements:
                    widget.elements.whereType<StickerElement>().toList(),
                constraints: constraints,
              ),
              // Text elements (read-only)
              ..._buildTextElements(constraints),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMedia() {
    if (widget.media.type == StoryType.video) {
      final vc = _videoController;
      if (vc != null && vc.value.isInitialized) {
        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: vc.value.size.width,
            height: vc.value.size.height,
            child: VideoPlayer(vc),
          ),
        );
      }
      return const ColoredBox(color: Colors.black);
    }
    return Image.file(
      widget.media.file,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }

  List<Widget> _buildTextElements(BoxConstraints constraints) {
    return widget.elements.whereType<TextElement>().map((el) {
      final left = el.position.dx * constraints.maxWidth;
      final top = el.position.dy * constraints.maxHeight;
      return Positioned(
        left: left,
        top: top,
        child: Transform.rotate(
          angle: el.rotation,
          child: Transform.scale(
            scale: el.scale,
            child: Text(
              el.text,
              textAlign: el.align,
              style: TextStyle(
                color: el.color,
                fontSize: el.fontSize,
                fontFamily: el.fontFamily,
                shadows: el.hasShadow
                    ? const [Shadow(blurRadius: 4, color: Colors.black54)]
                    : null,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}

// ---------------------------------------------------------------------------
// Read-only drawing layer (no gesture detection, reuses the painter)

class _ReadOnlyDrawingLayer extends StatelessWidget {
  const _ReadOnlyDrawingLayer({required this.elements});
  final List<DrawingElement> elements;

  @override
  Widget build(BuildContext context) {
    // Reuse DrawingLayer in inactive mode — no GestureDetector, just paints.
    return IgnorePointer(
      child: CustomPaint(
        painter: _StrokeOnlyPainter(elements),
        size: Size.infinite,
      ),
    );
  }
}

class _StrokeOnlyPainter extends CustomPainter {
  _StrokeOnlyPainter(this.elements);
  final List<DrawingElement> elements;

  @override
  void paint(Canvas canvas, Size size) {
    for (final el in elements) {
      if (el.points.length < 2) continue;
      final paint = Paint()
        ..color = el.color
        ..strokeWidth = el.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..moveTo(el.points.first.dx * size.width,
            el.points.first.dy * size.height);
      for (int i = 1; i < el.points.length; i++) {
        path.lineTo(
            el.points[i].dx * size.width, el.points[i].dy * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_StrokeOnlyPainter old) => old.elements != elements;
}

// ---------------------------------------------------------------------------

class _ReadOnlyStickerLayer extends StatelessWidget {
  const _ReadOnlyStickerLayer({
    required this.elements,
    required this.constraints,
  });
  final List<StickerElement> elements;
  final BoxConstraints constraints;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: elements.map((el) {
        return Positioned(
          left: el.position.dx * constraints.maxWidth,
          top: el.position.dy * constraints.maxHeight,
          child: IgnorePointer(
            child: Transform.rotate(
              angle: el.rotation,
              child: Text(
                el.emoji,
                style: TextStyle(fontSize: el.size * el.scale),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}


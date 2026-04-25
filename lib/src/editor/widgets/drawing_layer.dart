import 'package:flutter/material.dart';

import '../../editor/models/story_element.dart';
import '../../editor/story_editor_controller.dart';
import 'package:uuid/uuid.dart';

class DrawingLayer extends StatefulWidget {
  const DrawingLayer({
    super.key,
    required this.controller,
    required this.isActive,
    this.currentColor = Colors.white,
    this.currentStrokeWidth = 4.0,
    this.currentStyle = StrokeStyle.solid,
  });

  final StoryEditorController controller;
  final bool isActive;
  final Color currentColor;
  final double currentStrokeWidth;
  final StrokeStyle currentStyle;

  @override
  State<DrawingLayer> createState() => _DrawingLayerState();
}

class _DrawingLayerState extends State<DrawingLayer> {
  static const _uuid = Uuid();
  final List<Offset> _currentPoints = [];

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => CustomPaint(
          painter: _StrokePainter(
            strokes: _drawingElements(),
            currentPoints: const [],
            currentColor: widget.currentColor,
            currentWidth: widget.currentStrokeWidth,
          ),
          size: Size.infinite,
        ),
      );
    }

    return GestureDetector(
      onPanStart: (d) => _currentPoints.add(_fractional(d.localPosition, context)),
      onPanUpdate: (d) {
        setState(() {
          _currentPoints.add(_fractional(d.localPosition, context));
        });
      },
      onPanEnd: (_) {
        if (_currentPoints.isNotEmpty) {
          widget.controller.addDrawingStroke(
            DrawingElement(
              id: _uuid.v4(),
              points: List.of(_currentPoints),
              color: widget.currentColor,
              strokeWidth: widget.currentStrokeWidth,
              style: widget.currentStyle,
            ),
          );
        }
        setState(() => _currentPoints.clear());
      },
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => CustomPaint(
          painter: _StrokePainter(
            strokes: _drawingElements(),
            currentPoints: List.of(_currentPoints),
            currentColor: widget.currentColor,
            currentWidth: widget.currentStrokeWidth,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }

  List<DrawingElement> _drawingElements() => widget.controller.elements
      .whereType<DrawingElement>()
      .toList();

  Offset _fractional(Offset local, BuildContext ctx) {
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;
    return Offset(local.dx / box.size.width, local.dy / box.size.height);
  }
}

class _StrokePainter extends CustomPainter {
  _StrokePainter({
    required this.strokes,
    required this.currentPoints,
    required this.currentColor,
    required this.currentWidth,
  });

  final List<DrawingElement> strokes;
  final List<Offset> currentPoints;
  final Color currentColor;
  final double currentWidth;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _drawStroke(canvas, size, stroke.points, stroke.color, stroke.strokeWidth);
    }
    if (currentPoints.isNotEmpty) {
      _drawStroke(canvas, size, currentPoints, currentColor, currentWidth);
    }
  }

  void _drawStroke(
    Canvas canvas,
    Size size,
    List<Offset> points,
    Color color,
    double width,
  ) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(points.first.dx * size.width, points.first.dy * size.height);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx * size.width, points[i].dy * size.height);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_StrokePainter old) =>
      old.strokes != strokes ||
      old.currentPoints != currentPoints ||
      old.currentColor != currentColor ||
      old.currentWidth != currentWidth;
}

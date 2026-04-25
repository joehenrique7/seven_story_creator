import 'package:flutter/material.dart';

import '../models/story_element.dart';
import '../story_editor_controller.dart';

class StickerLayer extends StatefulWidget {
  const StickerLayer({
    super.key,
    required this.controller,
    this.readOnly = false,
  });

  final StoryEditorController controller;
  final bool readOnly;

  @override
  State<StickerLayer> createState() => _StickerLayerState();
}

class _StickerLayerState extends State<StickerLayer> {
  // Per-element baseline for multi-touch gestures
  final Map<String, ({double scale, double rotation})> _gestureBaselines = {};

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final stickers = widget.controller.elements
            .whereType<StickerElement>()
            .toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: stickers.map((el) {
                final left = el.position.dx * constraints.maxWidth;
                final top = el.position.dy * constraints.maxHeight;
                return Positioned(
                  left: left,
                  top: top,
                  child: _buildSticker(el, constraints),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  Widget _buildSticker(StickerElement el, BoxConstraints constraints) {
    final child = Transform.rotate(
      angle: el.rotation,
      child: Text(
        el.emoji,
        style: TextStyle(fontSize: el.size * el.scale),
      ),
    );

    if (widget.readOnly) return child;

    return GestureDetector(
      onTap: () => widget.controller.selectElement(el.id),
      onScaleStart: (_) {
        _gestureBaselines[el.id] = (scale: el.scale, rotation: el.rotation);
      },
      onScaleUpdate: (d) {
        final baseline = _gestureBaselines[el.id];
        if (baseline == null) return;
        widget.controller.updateElement(
          el.id,
          el.copyWith(
            scale: (baseline.scale * d.scale).clamp(0.1, 10.0),
            rotation: baseline.rotation + d.rotation,
            position: el.position +
                Offset(
                  d.focalPointDelta.dx / constraints.maxWidth,
                  d.focalPointDelta.dy / constraints.maxHeight,
                ),
          ),
        );
      },
      onScaleEnd: (_) => _gestureBaselines.remove(el.id),
      onLongPress: () => widget.controller.removeElement(el.id),
      child: child,
    );
  }
}

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
  // Baseline de escala/rotação capturado no início da pinça sobre o adesivo.
  ({double scale, double rotation})? _xfBaseline;

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
    final selected = !widget.readOnly && widget.controller.selectedId == el.id;
    final child = Transform.rotate(
      angle: el.rotation,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: selected
            ? BoxDecoration(
                border: Border.all(color: Colors.white70),
                borderRadius: BorderRadius.circular(4),
              )
            : null,
        child: Text(
          el.emoji,
          style: TextStyle(fontSize: el.size * el.scale),
        ),
      ),
    );

    if (widget.readOnly) return child;

    return GestureDetector(
      onTapDown: (_) => widget.controller.selectElement(el.id),
      onLongPress: () => widget.controller.removeElement(el.id),
      // Mover (1 dedo) / redimensionar / rotacionar (2 dedos) começando em cima
      // do próprio emoji. onScale* cobre também o arraste de um dedo via
      // focalPointDelta, então não precisamos de onPan (que conflitaria).
      onScaleStart: (_) {
        widget.controller.selectElement(el.id);
        _xfBaseline = (scale: el.scale, rotation: el.rotation);
      },
      onScaleUpdate: (d) {
        final b = _xfBaseline;
        final current =
            widget.controller.selectedElement as StickerElement?;
        if (b == null || current == null || current.id != el.id) return;
        widget.controller.updateElement(
          el.id,
          current.copyWith(
            scale: (b.scale * d.scale).clamp(0.1, 10.0),
            rotation: b.rotation + d.rotation,
            position: current.position +
                Offset(
                  d.focalPointDelta.dx / constraints.maxWidth,
                  d.focalPointDelta.dy / constraints.maxHeight,
                ),
          ),
        );
      },
      onScaleEnd: (_) => _xfBaseline = null,
      child: child,
    );
  }
}

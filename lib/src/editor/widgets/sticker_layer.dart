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
                  child: _buildSticker(el),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  Widget _buildSticker(StickerElement el) {
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
      child: child,
    );
  }
}

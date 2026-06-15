import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/story_element.dart';
import '../story_editor_controller.dart';

/// Interactive layer for [TextElement]s on the editor canvas.
/// Tap to select, double-tap to edit, long-press to remove. Mover/escalar/rotacionar
/// é tratado pela camada de gesto do canvas, sobre o elemento selecionado.
class TextLayer extends StatefulWidget {
  const TextLayer({
    super.key,
    required this.controller,
    required this.onEditRequest,
  });

  final StoryEditorController controller;
  final void Function(TextElement) onEditRequest;

  @override
  State<TextLayer> createState() => _TextLayerState();
}

class _TextLayerState extends State<TextLayer> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final texts =
            widget.controller.elements.whereType<TextElement>().toList();
        return LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: texts
                .map((el) => Positioned(
                      left: el.position.dx * constraints.maxWidth,
                      top: el.position.dy * constraints.maxHeight,
                      child: _buildItem(el),
                    ))
                .toList(),
          ),
        );
      },
    );
  }

  Widget _buildItem(TextElement el) {
    final selected = widget.controller.selectedId == el.id;
    final content = Transform.rotate(
      angle: el.rotation,
      child: Transform.scale(
        scale: el.scale,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: selected
              ? BoxDecoration(
                  border: Border.all(color: Colors.white70),
                  borderRadius: BorderRadius.circular(4),
                )
              : null,
          child: Text(
            el.text,
            textAlign: el.align,
            style: _applyFont(
              el.fontFamily,
              TextStyle(
                color: el.color,
                fontSize: el.fontSize,
                shadows: el.hasShadow
                    ? const [Shadow(blurRadius: 4, color: Colors.black54)]
                    : null,
              ),
            ),
          ),
        ),
      ),
    );

    return GestureDetector(
      onTapDown: (_) => widget.controller.selectElement(el.id),
      onDoubleTap: () => widget.onEditRequest(el),
      onLongPress: () => widget.controller.removeElement(el.id),
      child: content,
    );
  }

  static TextStyle _applyFont(String? family, TextStyle base) {
    if (family == null) return base;
    try {
      return GoogleFonts.getFont(family, textStyle: base);
    } catch (_) {
      return base;
    }
  }
}

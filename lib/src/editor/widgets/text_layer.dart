import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/story_element.dart';
import '../story_editor_controller.dart';

/// Interactive layer for [TextElement]s on the editor canvas.
/// Tap to select, double-tap to edit, long-press to remove. Mover/escalar/rotacionar
/// funciona tanto sobre o próprio elemento (aqui, via [GestureDetector.onScaleUpdate])
/// quanto pela camada de gesto do canvas — o toque em cima do texto não fica mais
/// preso ao hit-test do glifo.
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
  // Baseline de escala/rotação capturado no início da pinça sobre o elemento.
  ({double scale, double rotation})? _xfBaseline;

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
                      child: _buildItem(el, constraints),
                    ))
                .toList(),
          ),
        );
      },
    );
  }

  Widget _buildItem(TextElement el, BoxConstraints constraints) {
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
      // Mover (1 dedo) / redimensionar / rotacionar (2 dedos) começando em cima
      // do próprio texto. onScale* cobre também o arraste de um dedo via
      // focalPointDelta, então não precisamos de onPan (que conflitaria).
      onScaleStart: (_) {
        widget.controller.selectElement(el.id);
        _xfBaseline = (scale: el.scale, rotation: el.rotation);
      },
      onScaleUpdate: (d) {
        final b = _xfBaseline;
        final current =
            widget.controller.selectedElement as TextElement?;
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
